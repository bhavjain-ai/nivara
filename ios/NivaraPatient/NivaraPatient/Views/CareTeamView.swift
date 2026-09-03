import SwiftUI

struct CareTeamView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @State private var selectedMember: CareTeamMember?

    private var profile: PatientProfile { viewModel.profile }

    /// One card per role that actually has someone assigned — the physician
    /// always shows (falls back to the profile's physician name even with no
    /// logged calls yet); dietician/coach only show once they've made contact.
    private var teamMembers: [CareTeamMember] {
        CoordinatorRole.allCases.compactMap { role in
            let entries = profile.outreachLog
                .filter { $0.coordinatorRole == role }
                .sorted { $0.date < $1.date }
            let name = entries.last?.coordinatorName ?? (role == .physician ? profile.physicianName : nil)
            guard let name else { return nil }
            return CareTeamMember(role: role, name: name, entries: entries)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageTitle(text: "Care Team")
                        .padding(.top, 8)
                    coachingProgressCard
                    teamCard
                    goalsSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(NivaraColor.cream)
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedMember) { member in
            CareTeamConversationView(member: member)
        }
    }

    private var coachingProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(profile.coachingTier.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(profile.coachingTier.color)
                Spacer()
                Text(profile.coachingTier.cadence)
                    .font(.caption)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ProgressView(value: Double(profile.coachingCallsCompleted), total: Double(profile.coachingCallsTarget))
                .tint(NivaraColor.forestGreen)

            Text("\(profile.coachingCallsCompleted) of \(profile.coachingCallsTarget) check-in calls completed this program")
                .font(.caption)
                .foregroundStyle(NivaraColor.textSecondary)
        }
        .nivaraCard()
    }

    private var teamCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR CARE TEAM")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)

            HStack(alignment: .top, spacing: 10) {
                ForEach(teamMembers) { member in
                    teamMemberButton(member)
                }
            }

            contactUsButton
        }
        .nivaraCard()
    }

    private func teamMemberButton(_ member: CareTeamMember) -> some View {
        Button {
            selectedMember = member
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(NivaraColor.sageGreen)
                    Image(systemName: member.role.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(NivaraColor.forestGreen)
                }
                .frame(width: 56, height: 56)

                Text(member.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(member.role.rawValue)
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)

                Text(member.lastContact?.summary ?? "No messages yet")
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var contactUsButton: some View {
        NavigationLink {
            ContactUsView()
        } label: {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                Text("Got a Question? Contact Us")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(NivaraColor.forestGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR GOALS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)

            if profile.smartGoals.isEmpty {
                Text("No goals set yet.")
                    .font(.footnote)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ForEach(profile.smartGoals) { goal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        PillLabel(text: goal.category)
                        Spacer()
                        PillLabel(text: goal.status.rawValue, color: goal.status.color, background: goal.status.color.opacity(0.15))
                    }
                    Text(goal.description)
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textPrimary)
                    if let note = goal.progressNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    Text("\(NivaraDate.short.string(from: goal.setDate)) → \(NivaraDate.short.string(from: goal.targetDate))")
                        .font(.caption2)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                .padding(.vertical, 8)
                Divider()
            }
        }
        .nivaraCard()
    }
}

#Preview {
    CareTeamView().environmentObject(PatientViewModel())
}
