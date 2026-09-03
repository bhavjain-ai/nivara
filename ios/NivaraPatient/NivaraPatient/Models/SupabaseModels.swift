import Foundation

/// Wire-format models for talking to Supabase — kept separate from
/// PatientModels.swift/VitalModels.swift, which describe local/demo state.
/// Column names use explicit CodingKeys (snake_case) rather than relying on
/// any SDK-default key conversion, so the mapping to
/// supabase/migrations/0001_init.sql is unambiguous by inspection.

/// The payload sent once, right after onboarding's consent step, to create
/// this device's patient row. See SupabaseService.registerPatient.
struct PatientRegistration: Encodable {
    let authUserId: UUID
    let deviceIdentifier: String
    let firstName: String
    let lastName: String
    let dateOfBirth: String? // yyyy-MM-dd, matches Postgres `date`
    let physicianName: String?
    let physicianPhone: String?
    let conditions: [String]
    let bpTargetSystolic: Int?
    let bpTargetDiastolic: Int?
    let bpTargetLabel: String?
    let hba1cTier: Int?
    let hba1cTargetLabel: String?
    let hba1cTargetValue: Double?
    let coachingTier: String?
    let coachingCallsCompleted: Int
    let coachingCallsTarget: Int
    let shareWithFamilyMember: Bool
    let familyMemberName: String?
    let familyMemberRelationship: String?
    let familyMemberPhone: String?
    let acceptedInformedConsentAt: String
    let acceptedPrivacyConsentAt: String

    enum CodingKeys: String, CodingKey {
        case authUserId = "auth_user_id"
        case deviceIdentifier = "device_identifier"
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case physicianName = "physician_name"
        case physicianPhone = "physician_phone"
        case conditions
        case bpTargetSystolic = "bp_target_systolic"
        case bpTargetDiastolic = "bp_target_diastolic"
        case bpTargetLabel = "bp_target_label"
        case hba1cTier = "hba1c_tier"
        case hba1cTargetLabel = "hba1c_target_label"
        case hba1cTargetValue = "hba1c_target_value"
        case coachingTier = "coaching_tier"
        case coachingCallsCompleted = "coaching_calls_completed"
        case coachingCallsTarget = "coaching_calls_target"
        case shareWithFamilyMember = "share_with_family_member"
        case familyMemberName = "family_member_name"
        case familyMemberRelationship = "family_member_relationship"
        case familyMemberPhone = "family_member_phone"
        case acceptedInformedConsentAt = "accepted_informed_consent_at"
        case acceptedPrivacyConsentAt = "accepted_privacy_consent_at"
    }
}

/// A row from the `messages` table. `createdAt`/`readAt` are decoded as raw
/// strings (not `Date`) deliberately — that sidesteps needing to match
/// whatever default date-decoding behavior the Supabase SDK's JSONDecoder
/// uses internally, which isn't documented at the level of precision this
/// needs. `createdDate` below parses it with a formatter this file controls
/// directly, robust to Postgres's timestamptz fractional-seconds format.
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let patientId: UUID
    let coordinatorRole: String // matches CoordinatorRole.rawValue
    let senderType: String // "patient" | "care_team" | "ai_agent"
    let senderName: String
    let body: String
    let readAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case coordinatorRole = "coordinator_role"
        case senderType = "sender_type"
        case senderName = "sender_name"
        case body
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var createdDate: Date {
        SupabaseDate.parse(createdAt) ?? Date()
    }
}

/// The payload for a new outgoing patient message (no id/created_at — the
/// database assigns those).
struct NewChatMessage: Encodable {
    let patientId: UUID
    let coordinatorRole: String
    let senderType: String
    let senderName: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case coordinatorRole = "coordinator_role"
        case senderType = "sender_type"
        case senderName = "sender_name"
        case body
    }
}

enum SupabaseDate {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnly: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        withFractionalSeconds.date(from: string) ?? plain.date(from: string)
    }

    /// yyyy-MM-dd, for Postgres `date` columns (e.g. date_of_birth).
    static func dateOnlyString(from date: Date) -> String {
        dateOnly.string(from: date)
    }
}
