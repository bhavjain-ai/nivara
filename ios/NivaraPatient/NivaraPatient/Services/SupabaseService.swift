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
    /// scope note in the README.
    static func registerPatient(onboarding: OnboardingStore, demoProfile: PatientProfile) async {
        guard let client else { return }
        do {
            let userId = try await ensureSignedIn()
            let now = ISO8601DateFormatter().string(from: Date())

            let registration = PatientRegistration(
                authUserId: userId,
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
}

enum SupabaseServiceError: Error {
    case notConfigured
}
