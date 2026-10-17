import Foundation

enum Condition: String, Codable, CaseIterable {
    case hypertension = "Hypertension"
    case diabetes = "Diabetes"
}

struct Medication: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let drugClass: String
    let dose: String
    let frequency: String
    let startDate: Date

    init(id: UUID = UUID(), name: String, drugClass: String, dose: String, frequency: String, startDate: Date) {
        self.id = id
        self.name = name
        self.drugClass = drugClass
        self.dose = dose
        self.frequency = frequency
        self.startDate = startDate
    }
}

/// A single logged medication change (started, stopped, dose adjusted) shown
/// on the Medications tab under the current medication list.
struct MedicationChange: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let description: String
    let relatedCondition: Condition

    init(id: UUID = UUID(), date: Date, description: String, relatedCondition: Condition) {
        self.id = id
        self.date = date
        self.description = description
        self.relatedCondition = relatedCondition
    }
}

enum CoachingTier: String, Codable {
    case highTouch = "High-touch"
    case moderateTouch = "Moderate-touch"
    case maintenanceTouch = "Maintenance-touch"

    var cadence: String {
        switch self {
        case .highTouch: return "Weekly calls"
        case .moderateTouch: return "Biweekly calls"
        case .maintenanceTouch: return "Monthly calls"
        }
    }

    func displayName(for language: AppLanguage) -> String {
        let key: String
        switch self {
        case .highTouch: key = "coaching_tier_high_touch"
        case .moderateTouch: key = "coaching_tier_moderate_touch"
        case .maintenanceTouch: key = "coaching_tier_maintenance_touch"
        }
        return Translations.table[key]?[language] ?? Translations.table[key]?[.english] ?? rawValue
    }

    func cadence(for language: AppLanguage) -> String {
        let key: String
        switch self {
        case .highTouch: key = "coaching_tier_cadence_weekly"
        case .moderateTouch: key = "coaching_tier_cadence_biweekly"
        case .maintenanceTouch: key = "coaching_tier_cadence_monthly"
        }
        return Translations.table[key]?[language] ?? Translations.table[key]?[.english] ?? cadence
    }
}

/// The three people on a patient's care team shown on the Care Team page.
/// Declaration order here is also the display order (physician, dietician,
/// coach).
enum CoordinatorRole: String, Codable, CaseIterable {
    case physician = "Physician"
    case dietician = "Dietician"
    case coach = "Coach"

    var icon: String {
        switch self {
        case .physician: return "stethoscope"
        case .dietician: return "leaf.fill"
        case .coach: return "figure.walk"
        }
    }

    func displayName(for language: AppLanguage) -> String {
        let key: String
        switch self {
        case .physician: key = "coordinator_role_physician"
        case .dietician: key = "coordinator_role_dietician"
        case .coach: key = "coordinator_role_coach"
        }
        return Translations.table[key]?[language] ?? Translations.table[key]?[.english] ?? rawValue
    }
}

struct OutreachCall: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let coordinatorName: String
    let coordinatorRole: CoordinatorRole
    let callType: String
    let durationMin: Int
    let topics: [String]
    let summary: String

    init(id: UUID = UUID(), date: Date, coordinatorName: String, coordinatorRole: CoordinatorRole, callType: String, durationMin: Int, topics: [String], summary: String) {
        self.id = id
        self.date = date
        self.coordinatorName = coordinatorName
        self.coordinatorRole = coordinatorRole
        self.callType = callType
        self.durationMin = durationMin
        self.topics = topics
        self.summary = summary
    }
}

enum SmartGoalStatus: String, Codable {
    case onTrack = "On Track"
    case atRisk = "At Risk"
    case met = "Met"
    case partiallyMet = "Partially Met"
    case notMet = "Not Met"

    func displayName(for language: AppLanguage) -> String {
        let key: String
        switch self {
        case .onTrack: key = "goal_status_on_track"
        case .atRisk: key = "goal_status_at_risk"
        case .met: key = "goal_status_met"
        case .partiallyMet: key = "goal_status_partially_met"
        case .notMet: key = "goal_status_not_met"
        }
        return Translations.table[key]?[language] ?? Translations.table[key]?[.english] ?? rawValue
    }
}

/// `SmartGoal.category` is a free-form `String` (set by the care team via the
/// dashboard, e.g. "Diet", "Physical Activity") rather than a fixed enum, so
/// it can't get a `displayName(for:)` the way the enums above do. This looks
/// up a translation for the known category names used by the demo/dashboard
/// data and falls back to the original English text for anything not in the
/// table, so a category the dashboard adds later still displays (in English)
/// instead of crashing or showing a blank.
func goalCategoryDisplayName(_ category: String, for language: AppLanguage) -> String {
    let key = "goal_category_" + category.lowercased().replacingOccurrences(of: " ", with: "_")
    return Translations.table[key]?[language] ?? category
}

struct SmartGoal: Identifiable, Codable, Equatable {
    let id: UUID
    let category: String
    let description: String
    let setDate: Date
    let targetDate: Date
    let status: SmartGoalStatus
    let progressNote: String?

    init(id: UUID = UUID(), category: String, description: String, setDate: Date, targetDate: Date, status: SmartGoalStatus, progressNote: String? = nil) {
        self.id = id
        self.category = category
        self.description = description
        self.setDate = setDate
        self.targetDate = targetDate
        self.status = status
        self.progressNote = progressNote
    }
}

/// The patient's clinical + care-coordination profile. In this self-contained
/// demo build this is bundled locally (see DemoPatientData.swift), mirroring the
/// web dashboard's mock-data.ts. Live vitals (BP/glucose) still come from real
/// BLE devices via BLEManager — this profile only supplies the slower-moving
/// data a physician/coach would set (targets, meds, coaching, goals).
struct PatientProfile {
    let name: String
    let physicianName: String
    let physicianPhone: String
    let conditions: [Condition]
    let bpTarget: BPTarget?
    let hba1cTier: HbA1cTierInfo?
    let medications: [Medication]
    let medicationHistory: [MedicationChange]
    let coachingTier: CoachingTier
    let coachingCallsCompleted: Int
    let coachingCallsTarget: Int
    let outreachLog: [OutreachCall]
    let smartGoals: [SmartGoal]
}
