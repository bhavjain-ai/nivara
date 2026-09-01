import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @Binding var selectedTab: AppTab

    private var profile: PatientProfile { viewModel.profile }

    private var firstName: String {
        profile.name.components(separatedBy: " ").first ?? profile.name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(NivaraDate.greeting()), \(firstName)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text(Date(), style: .date)
                            .font(.subheadline)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    .padding(.top, 8)

                    if let reassurance = viewModel.postMeasurementMessage {
                        reassuranceCard(reassurance)
                    }

                    measurementStatusCard

                    reviewTrendsCard

                    if let goal = profile.smartGoals.first {
                        goalPreview(goal)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(NivaraColor.cream)
            .navigationBarHidden(true)
        }
    }

    private func reassuranceCard(_ reassurance: PostMeasurementMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reassurance.level == .normal ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(reassurance.level.color)
            Text(reassurance.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NivaraColor.textPrimary)
        }
        .padding(14)
        .background(reassurance.level.backgroundColor)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(reassurance.level.color.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .transition(.opacity)
    }

    @ViewBuilder
    private var measurementStatusCard: some View {
        if viewModel.tookReadingToday {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(NivaraColor.forestGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thank you for taking your measurement today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    Text("Your care team can see your latest reading.")
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .nivaraCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(NivaraColor.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You haven't taken a measurement yet today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Text("Connect your glucose meter to check in.")
                            .font(.caption)
                            .foregroundStyle(NivaraColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                NavigationLink {
                    DeviceConnectionView()
                } label: {
                    Text("Take a Measurement")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(NivaraColor.forestGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .nivaraCard()
        }
    }

    private var reviewTrendsCard: some View {
        Button {
            selectedTab = .myHealth
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3)
                    .foregroundStyle(NivaraColor.forestGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review your recent measurements")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    Text("See your latest readings and trends")
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            .nivaraCard()
        }
        .buttonStyle(.plain)
    }

    private func goalPreview(_ goal: SmartGoal) -> some View {
        Button {
            selectedTab = .careTeam
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Your goal", systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    PillLabel(text: goal.status.rawValue, color: goal.status.color, background: goal.status.color.opacity(0.15))
                }
                Text(goal.description)
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .nivaraCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home)).environmentObject(PatientViewModel())
}
