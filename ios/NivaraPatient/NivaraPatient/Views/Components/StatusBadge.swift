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
    var color: Color = .secondary
    var background: Color = Color(.tertiarySystemFill)

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
