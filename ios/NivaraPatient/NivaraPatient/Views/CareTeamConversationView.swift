import SwiftUI

/// A chat-thread-style read of everything one care team member has logged
/// with the patient, oldest at top, most recent at the bottom.
struct CareTeamConversationView: View {
    let member: CareTeamMember

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if member.entries.isEmpty {
                        Text("No messages yet.")
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                            .padding(.top, 20)
                    }

                    ForEach(member.entries) { entry in
                        messageBubble(entry)
                    }
                }
                .padding()
            }
            .background(NivaraColor.cream)
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NivaraColor.forestGreen)
                }
            }
        }
    }

    private func messageBubble(_ entry: OutreachCall) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.callType)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.forestGreen)
                Spacer()
                Text(NivaraDate.shortWithTime.string(from: entry.date))
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            Text(entry.summary)
                .font(.subheadline)
                .foregroundStyle(NivaraColor.textPrimary)

            if !entry.topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.topics, id: \.self) { topic in
                        PillLabel(text: topic)
                    }
                }
            }
        }
        .padding(12)
        .background(NivaraColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NivaraColor.border))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    CareTeamConversationView(
        member: CareTeamMember(role: .dietician, name: "Rohan Bhatt", entries: DemoPatientData.patient.outreachLog)
    )
}
