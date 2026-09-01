import Foundation

/// One of the patient's three care team members (physician, dietician, coach),
/// derived from `PatientProfile.outreachLog` grouped by role. Not persisted —
/// computed at view-render time.
struct CareTeamMember: Identifiable {
    let role: CoordinatorRole
    let name: String
    /// Chronological, oldest first — the last element is the most recent contact.
    let entries: [OutreachCall]

    var id: String { role.rawValue }

    var lastContact: OutreachCall? { entries.last }
}
