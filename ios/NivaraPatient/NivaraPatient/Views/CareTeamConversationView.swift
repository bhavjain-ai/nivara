import SwiftUI

/// A chat-thread-style read of everything one care team member has logged
/// with the patient (oldest at top), plus — below that — a real, live
/// two-way message thread with that same person, backed by Supabase
/// (ChatViewModel). The composer is disabled with an explanatory note when
/// no Supabase project is configured, so the rest of the app keeps working
/// on local/demo data either way.
struct CareTeamConversationView: View {
    let member: CareTeamMember

    @StateObject private var chat: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    init(member: CareTeamMember) {
        self.member = member
        _chat = StateObject(wrappedValue: ChatViewModel(role: member.role))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if member.entries.isEmpty && chat.messages.isEmpty {
                            Text("No messages yet.")
                                .font(.subheadline)
                                .foregroundStyle(NivaraColor.textSecondary)
                                .padding(.top, 20)
                        }

                        ForEach(member.entries) { entry in
                            messageBubble(entry)
                        }

                        if !chat.messages.isEmpty {
                            Divider().padding(.vertical, 4)
                        }

                        ForEach(chat.messages) { message in
                            chatBubble(message)
                        }
                    }
                    .padding()
                }
                .background(NivaraColor.cream)

                composer
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
        .task {
            await chat.start()
        }
        .onDisappear {
            chat.stop()
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

    private func chatBubble(_ message: ChatMessage) -> some View {
        let isPatient = message.senderType == "patient"
        return HStack {
            if isPatient { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                Text(message.senderName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isPatient ? .white.opacity(0.8) : NivaraColor.textSecondary)
                Text(message.body)
                    .font(.subheadline)
                    .foregroundStyle(isPatient ? .white : NivaraColor.textPrimary)
            }
            .padding(10)
            .background(isPatient ? NivaraColor.forestGreen : NivaraColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isPatient ? Color.clear : NivaraColor.border)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isPatient { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !chat.isAvailable {
                Text("Messaging isn't set up in this build yet — see the README's Supabase setup section.")
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)
                    .padding(.horizontal)
            }
            HStack(spacing: 8) {
                TextField("Message \(member.name)…", text: $chat.draft, axis: .vertical)
                    .padding(10)
                    .background(NivaraColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .disabled(!chat.isAvailable)

                let canSend = chat.isAvailable && !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button {
                    Task { await chat.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend ? NivaraColor.forestGreen : NivaraColor.border)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(NivaraColor.surface)
    }
}

#Preview {
    CareTeamConversationView(
        member: CareTeamMember(role: .dietician, name: "Rohan Bhatt", entries: DemoPatientData.patient.outreachLog)
    )
}
