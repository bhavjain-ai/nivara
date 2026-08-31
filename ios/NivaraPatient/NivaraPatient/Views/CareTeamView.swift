import SwiftUI

struct CareTeamView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(profile.coachingTier.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(profile.coachingTier.color)
                            Spacer()
                            Text(profile.coachingTier.cadence)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: Double(profile.coachingCallsCompleted), total: Double(profile.coachingCallsTarget))
                            .tint(NivaraColor.navy)

                        Text("\(profile.coachingCallsCompleted) of \(profile.coachingCallsTarget) check-in calls completed this program")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your Care Team Outreach")
                }

                Section("Recent Calls") {
                    if profile.outreachLog.isEmpty {
                        Text("No calls logged yet.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(profile.outreachLog) { call in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(call.coordinatorName).fontWeight(.semibold)
                                PillLabel(text: call.coordinatorRole.rawValue)
                                Spacer()
                                Text(NivaraDate.short.string(from: call.date))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(call.callType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(call.summary)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Your Goals") {
                    if profile.smartGoals.isEmpty {
                        Text("No goals set yet.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
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
                            if let note = goal.progressNote {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(NivaraDate.short.string(from: goal.setDate)) → \(NivaraDate.short.string(from: goal.targetDate))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Care Team")
        }
    }
}

#Preview {
    CareTeamView().environmentObject(PatientViewModel())
}
