import SwiftUI

struct VitalCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let subLabel: String?
    let status: VitalStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let subLabel {
                Text(subLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let status {
                Text(status.message)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(status.level.color)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status?.level.backgroundColor ?? Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(status?.level.color.opacity(0.35) ?? Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
