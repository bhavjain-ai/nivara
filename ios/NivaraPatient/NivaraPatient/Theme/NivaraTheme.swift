import SwiftUI

enum NivaraColor {
    static let navy = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x5F / 255)
    static let critical = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let warning = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x06 / 255)
    static let normal = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
    static let criticalBackground = Color(red: 0xFE / 255, green: 0xF2 / 255, blue: 0xF2 / 255)
    static let warningBackground = Color(red: 0xFF / 255, green: 0xFB / 255, blue: 0xEB / 255)
    static let normalBackground = Color(red: 0xF0 / 255, green: 0xFD / 255, blue: 0xF4 / 255)
}

extension VitalStatusLevel {
    var color: Color {
        switch self {
        case .critical: return NivaraColor.critical
        case .warning: return NivaraColor.warning
        case .normal: return NivaraColor.normal
        }
    }

    var backgroundColor: Color {
        switch self {
        case .critical: return NivaraColor.criticalBackground
        case .warning: return NivaraColor.warningBackground
        case .normal: return NivaraColor.normalBackground
        }
    }

    var label: String {
        switch self {
        case .critical: return "Needs Attention"
        case .warning: return "Slightly Off Target"
        case .normal: return "On Target"
        }
    }
}

extension CoachingTier {
    var color: Color {
        switch self {
        case .highTouch: return NivaraColor.critical
        case .moderateTouch: return NivaraColor.warning
        case .maintenanceTouch: return NivaraColor.normal
        }
    }
}

extension SmartGoalStatus {
    var color: Color {
        switch self {
        case .met: return NivaraColor.normal
        case .onTrack: return .blue
        case .partiallyMet: return NivaraColor.warning
        case .atRisk: return .orange
        case .notMet: return NivaraColor.critical
        }
    }
}
