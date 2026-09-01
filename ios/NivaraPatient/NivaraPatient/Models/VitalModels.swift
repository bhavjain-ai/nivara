import Foundation

enum GlucoseSampleType: String, Codable, CaseIterable {
    case fasting
    case postMeal = "post-meal"

    var displayName: String {
        switch self {
        case .fasting: return "Fasting"
        case .postMeal: return "Post-meal (2hr)"
        }
    }
}

enum ReadingSource: String, Codable {
    case bleDevice = "BLE Device"
    case manual = "Manual Entry"
    case demo = "Demo Data"
}

struct BPReading: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let systolic: Int
    let diastolic: Int
    let pulse: Int?
    let source: ReadingSource

    init(id: UUID = UUID(), date: Date, systolic: Int, diastolic: Int, pulse: Int? = nil, source: ReadingSource) {
        self.id = id
        self.date = date
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.source = source
    }
}

struct GlucoseReading: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let glucoseMgDl: Int
    let sampleType: GlucoseSampleType
    let source: ReadingSource

    init(id: UUID = UUID(), date: Date, glucoseMgDl: Int, sampleType: GlucoseSampleType, source: ReadingSource) {
        self.id = id
        self.date = date
        self.glucoseMgDl = glucoseMgDl
        self.sampleType = sampleType
        self.source = source
    }
}

struct HbA1cReading: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let value: Double

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

/// A patient's individualized blood-pressure target (IGH-V 2025-2026) — not one
/// flat number for everyone; varies by diabetes-comorbid status, other high-risk
/// conditions, and age.
struct BPTarget: Codable, Equatable {
    let systolic: Int
    let diastolic: Int
    let label: String
}

/// RSSDI/ADA individualized HbA1c target tier (1 = 6.5%, 2 = <7.0%, 3 = 7.5-8.0%).
struct HbA1cTierInfo: Codable, Equatable {
    let tier: Int
    let targetLabel: String
    let targetValue: Double
}

enum GlucosePopulationTier: String, Codable {
    case standard
    case relaxed
}

struct GlucoseTargetRange: Codable, Equatable {
    let population: GlucosePopulationTier
    let fastingLow: Int
    let fastingHigh: Int
    let postprandialHigh: Int
}

enum VitalStatusLevel: String, Codable {
    case critical
    case warning
    case normal
}

struct VitalStatus: Equatable {
    let level: VitalStatusLevel
    let message: String
    let guideline: String
}

/// The reassuring, patient-facing message shown right after a fresh BLE
/// reading comes in — distinct from `VitalStatus.message`, which is a
/// precise clinical description; this is deliberately warmer and sets
/// expectations about follow-up.
struct PostMeasurementMessage: Equatable {
    let level: VitalStatusLevel
    let text: String
}

/// A brief, self-dismissing confirmation banner — distinct from
/// `PostMeasurementMessage` (a clinical reassurance) in that this only
/// confirms the mechanical fact that a reading was captured and saved to
/// history, so a patient watching the screen has something concrete to
/// point to if a reading ever seems to have gone missing.
struct ToastMessage: Identifiable, Equatable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}
