import Foundation
import Supabase

/// Thin wrapper around the shared SupabaseClient, plus the two things this
/// app needs it for: device-linked patient registration (see
/// `registerPatient`) and the Care Team chat feature (see ChatViewModel,
/// which calls `fetchMyPatientId`).
///
/// Patients authenticate via Supabase Anonymous Auth — no email, phone, or
/// OTP. supabase-swift persists that session to the iOS Keychain by
/// default, which — like `DeviceIdentity` — survives app deletion and
/// reinstall. `DeviceIdentity.current` is stored alongside the patient row
/// as a secondary fingerprint for support-assisted recovery, not as the
/// primary auth mechanism; `auth.uid()` (from the anonymous session) is
/// what Row Level Security actually checks (see
/// supabase/migrations/0001_init.sql).
///
/// Everything here is best-effort: if `SupabaseConfig` hasn't been filled in
/// (fresh checkout, no project set up yet) or a network call fails, calls
/// no-op or fail silently (logged, not thrown to the UI). The app must keep
/// working entirely on local/demo data regardless of whether a Supabase
/// project exists — nothing about onboarding or the main app should ever
/// hard-fail because of this integration.
enum SupabaseService {
    static let client: SupabaseClient? = {
        guard SupabaseConfig.isConfigured else { return nil }
        return SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }()

    /// Returns the signed-in (anonymous) user's id, signing in for the first
    /// time if there's no existing Keychain-persisted session yet.
    private static func ensureSignedIn() async throws -> UUID {
        guard let client else { throw SupabaseServiceError.notConfigured }
        if let session = try? await client.auth.session {
            return session.user.id
        }
        let session = try await client.auth.signInAnonymously()
        return session.user.id
    }

    /// Resolves the join code a patient types in during onboarding (see
    /// OnboardingBasicInfoView) to a clinic. `clinics.join_code` is
    /// deliberately not selectable directly — this calls a SECURITY
    /// DEFINER Postgres function instead (see
    /// supabase/migrations/0005_clinic_join_codes.sql), which is the only
    /// path that can turn a code into a clinic id without the code itself
    /// ever being readable by a patient's anon session. Returns nil if the
    /// code is blank, matches no clinic, or Supabase is unreachable/not
    /// configured.
    static func resolveClinic(byJoinCode code: String) async -> Clinic? {
        guard let client else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            _ = try await ensureSignedIn()
            struct Params: Encodable { let code: String }
            let rows: [Clinic] = try await client
                .rpc("resolve_clinic_by_join_code", params: Params(code: trimmed))
                .execute()
                .value
            return rows.first
        } catch {
            print("SupabaseService.resolveClinic failed: \(error)")
            return nil
        }
    }

    /// Registers (or re-links) this device's patient row. Called once,
    /// right after onboarding's consent step completes — see
    /// OnboardingCompleteView. Safe to call more than once: a repeat
    /// registration for the same device fails the unique(device_identifier)
    /// constraint, which is treated as "already registered," not an error
    /// worth surfacing to the patient.
    ///
    /// `demoProfile` supplies the clinical fields (physician, targets,
    /// coaching tier) this pilot build still sources from the bundled demo
    /// data rather than real physician-entered enrollment — see the
    /// scope note in the README. `clinicId` is nil if the picker in
    /// onboarding found no clinics (or wasn't reached) — the patient row
    /// then has clinic_id = null until a clinic staff member backfills it
    /// (see SUPABASE_SETUP.md), same as patients registered before clinics
    /// existed at all.
    static func registerPatient(onboarding: OnboardingStore, demoProfile: PatientProfile, clinicId: UUID?) async {
        guard let client else { return }
        do {
            let userId = try await ensureSignedIn()
            let now = ISO8601DateFormatter().string(from: Date())

            let registration = PatientRegistration(
                authUserId: userId,
                clinicId: clinicId,
                deviceIdentifier: DeviceIdentity.current,
                firstName: onboarding.firstName,
                lastName: onboarding.lastName,
                dateOfBirth: onboarding.dateOfBirth.map(SupabaseDate.dateOnlyString),
                physicianName: demoProfile.physicianName,
                physicianPhone: demoProfile.physicianPhone,
                conditions: demoProfile.conditions.map(\.rawValue),
                bpTargetSystolic: demoProfile.bpTarget?.systolic,
                bpTargetDiastolic: demoProfile.bpTarget?.diastolic,
                bpTargetLabel: demoProfile.bpTarget?.label,
                hba1cTier: demoProfile.hba1cTier?.tier,
                hba1cTargetLabel: demoProfile.hba1cTier?.targetLabel,
                hba1cTargetValue: demoProfile.hba1cTier?.targetValue,
                coachingTier: demoProfile.coachingTier.rawValue,
                coachingCallsCompleted: demoProfile.coachingCallsCompleted,
                coachingCallsTarget: demoProfile.coachingCallsTarget,
                shareWithFamilyMember: onboarding.shareWithFamilyMember,
                familyMemberName: onboarding.shareWithFamilyMember ? onboarding.familyMemberName : nil,
                familyMemberRelationship: onboarding.shareWithFamilyMember ? onboarding.familyMemberRelationship : nil,
                familyMemberPhone: onboarding.shareWithFamilyMember ? onboarding.familyMemberPhone : nil,
                acceptedInformedConsentAt: now,
                acceptedPrivacyConsentAt: now
            )

            try await client
                .from("patients")
                .insert(registration)
                .execute()
        } catch {
            print("SupabaseService.registerPatient failed (continuing locally): \(error)")
        }
    }

    /// The calling device's own `patients.id` (not the same as the auth
    /// user id) — Row Level Security scopes the select to at most one row.
    /// Returns nil if not configured, not yet registered, or unreachable.
    static func fetchMyPatientId() async throws -> UUID? {
        guard let client else { return nil }
        _ = try await ensureSignedIn()
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("patients")
            .select("id")
            .execute()
            .value
        return rows.first?.id
    }

    /// Pushes a BP reading to Supabase, best-effort — same philosophy as
    /// `registerPatient`: VitalsStore's local save (what the UI and
    /// freshness logic actually depend on) already happened before this is
    /// ever called, so a failure here (not configured, not yet registered,
    /// network error) is logged and swallowed, never surfaced to the
    /// patient. Called from PatientViewModel right after a fresh BLE
    /// reading is saved locally — see onBPReading.
    static func pushBPReading(systolic: Int, diastolic: Int, pulse: Int?, date: Date, source: ReadingSource) async {
        guard client != nil else { return }
        do {
            guard let patientId = try await fetchMyPatientId() else { return }
            let reading = NewBPReading(
                patientId: patientId,
                systolic: systolic,
                diastolic: diastolic,
                pulse: pulse,
                source: source.supabaseValue,
                recordedAt: ISO8601DateFormatter().string(from: date)
            )
            try await client?
                .from("bp_readings")
                .insert(reading)
                .execute()
        } catch {
            print("SupabaseService.pushBPReading failed (continuing locally): \(error)")
        }
    }

    /// Pushes a glucose reading to Supabase, best-effort — see
    /// `pushBPReading`'s doc comment for the failure philosophy. Called
    /// from PatientViewModel right after a fresh BLE reading is saved
    /// locally — see onGlucoseReading. Note: a later retag (fasting vs.
    /// post-meal, via VitalsStore.retagLatestGlucose) is NOT currently
    /// re-synced to Supabase — the row pushed here keeps whatever
    /// sampleType was true at push time. Acceptable gap for now; worth
    /// revisiting if retagging turns out to be common.
    static func pushGlucoseReading(mgDl: Int, sampleType: GlucoseSampleType, date: Date, source: ReadingSource) async {
        guard client != nil else { return }
        do {
            guard let patientId = try await fetchMyPatientId() else { return }
            let reading = NewGlucoseReading(
                patientId: patientId,
                mgDl: mgDl,
                sampleType: sampleType.rawValue,
                source: source.supabaseValue,
                recordedAt: ISO8601DateFormatter().string(from: date)
            )
            try await client?
                .from("glucose_readings")
                .insert(reading)
                .execute()
        } catch {
            print("SupabaseService.pushGlucoseReading failed (continuing locally): \(error)")
        }
    }

    /// Fetches the signed-in patient's current medications from Supabase —
    /// the dashboard-edits-meds / iOS-reads-meds half of the sync (see
    /// src/app/api/patients/[id]/medications/route.ts on the dashboard
    /// side). RLS (medications_owner_read, supabase/migrations/0001_init.sql)
    /// scopes this to the calling patient's own row automatically. Returns
    /// [] on any failure — MedicationsView falls back to DemoPatientData in
    /// that case, same "never block on a backend issue" philosophy as
    /// everywhere else in this file.
    static func fetchMedications() async -> [Medication] {
        guard let client else { return [] }
        do {
            _ = try await ensureSignedIn()
            let rows: [SupabaseMedicationRow] = try await client
                .from("medications")
                .select("id, name, drug_class, dose, frequency, start_date")
                .order("start_date", ascending: false)
                .execute()
                .value
            return rows.map { $0.toMedication() }
        } catch {
            print("SupabaseService.fetchMedications failed (continuing with demo data): \(error)")
            return []
        }
    }

    /// Fetches the signed-in patient's medication change history — shows up
    /// in MedicationsView's "Recent Changes" card, which is how a dose/
    /// regimen change made on the dashboard actually becomes visible to the
    /// patient. See fetchMedications' doc comment for the failure philosophy.
    static func fetchMedicationHistory() async -> [MedicationChange] {
        guard let client else { return [] }
        do {
            _ = try await ensureSignedIn()
            let rows: [SupabaseMedicationChangeRow] = try await client
                .from("medication_changes")
                .select("id, description, related_condition, changed_at")
                .order("changed_at", ascending: false)
                .execute()
                .value
            return rows.compactMap { $0.toMedicationChange() }
        } catch {
            print("SupabaseService.fetchMedicationHistory failed (continuing with demo data): \(error)")
            return []
        }
    }
}

enum SupabaseServiceError: Error {
    case notConfigured
}
