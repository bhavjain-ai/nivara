import SwiftUI

struct StatusBadge: View {
    let level: VitalStatusLevel

    var body: some View {
        Text(level.label)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(level.color.opacity(0.15))
            .foregroundStyle(level.color)
            .clipShape(Capsule())
    }
}

struct PillLabel: View {
    let text: String
    // Explicit palette colors, not system-adaptive ones (.secondary,
    // Color(.tertiarySystemFill)) — those follow Dark Mode independently of
    // our fixed cream/white card backgrounds and can end up nearly
    // illegible (e.g. a light gray label on an already-light card).
    var color: Color = NivaraColor.textSecondary
    var background: Color = NivaraColor.sageGreen

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
