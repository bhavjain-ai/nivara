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
}

enum CoordinatorRole: String, Codable {
    case lifestyleCoach = "Lifestyle Coach"
    case nurse = "Nurse"
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
    let coachingTier: CoachingTier
    let coachingCallsCompleted: Int
    let coachingCallsTarget: Int
    let outreachLog: [OutreachCall]
    let smartGoals: [SmartGoal]
}
