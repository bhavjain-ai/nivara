import SwiftUI

/// Nivara Health brand palette — cream/off-white with forest green, matching
/// the brand's pitch deck and promotional materials.
enum NivaraColor {
    static let cream = Color(red: 0xF7 / 255, green: 0xF3 / 255, blue: 0xEA / 255)
    static let surface = Color.white
    static let forestGreen = Color(red: 0x1F / 255, green: 0x4B / 255, blue: 0x3A / 255)
    static let deepGreen = Color(red: 0x12 / 255, green: 0x35 / 255, blue: 0x26 / 255)
    static let sageGreen = Color(red: 0xE6 / 255, green: 0xF0 / 255, blue: 0xE8 / 255)
    static let textPrimary = Color(red: 0x1B / 255, green: 0x23 / 255, blue: 0x1E / 255)
    static let textSecondary = Color(red: 0x62 / 255, green: 0x70 / 255, blue: 0x6A / 255)
    static let border = Color(red: 0xE4 / 255, green: 0xE1 / 255, blue: 0xD6 / 255)

    static let critical = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let warning = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x06 / 255)
    static let normal = forestGreen
    static let criticalBackground = Color(red: 0xFE / 255, green: 0xF2 / 255, blue: 0xF2 / 255)
    static let warningBackground = Color(red: 0xFF / 255, green: 0xFB / 255, blue: 0xEB / 255)
    static let normalBackground = sageGreen
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
        case .maintenanceTouch: return NivaraColor.forestGreen
        }
    }
}

extension SmartGoalStatus {
    var color: Color {
        switch self {
        case .met: return NivaraColor.forestGreen
        case .onTrack: return Color(red: 0x2E / 255, green: 0x6B / 255, blue: 0x8F / 255)
        case .partiallyMet: return NivaraColor.warning
        case .atRisk: return Color(red: 0xC2 / 255, green: 0x6A / 255, blue: 0x1D / 255)
        case .notMet: return NivaraColor.critical
        }
    }
}

/// Reusable card surface styling used throughout the app: a white card with a
/// thin warm border, floating on the cream background.
struct NivaraCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(NivaraColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(NivaraColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func nivaraCard(padding: CGFloat = 16) -> some View {
        modifier(NivaraCard(padding: padding))
    }
}
