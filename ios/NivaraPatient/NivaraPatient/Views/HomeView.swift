import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if viewModel.justReceivedReading {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("New reading synced from your device")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NivaraColor.normal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(NivaraColor.normalBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity)
                    }

                    connectionBanner

                    VStack(alignment: .leading, spacing: 10) {
                        Text("TODAY'S READINGS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            if profile.conditions.contains(.hypertension) {
                                if let bp = viewModel.vitals.latestBP {
                                    VitalCard(
                                        icon: "heart.fill",
                                        title: "Blood Pressure",
                                        value: "\(bp.systolic)/\(bp.diastolic)",
                                        unit: "mmHg",
                                        subLabel: NivaraDate.relative(bp.date),
                                        status: viewModel.latestBPStatus
                                    )
                                } else {
                                    emptyVitalCard(icon: "heart.fill", title: "Blood Pressure")
                                }
                            }

                            if profile.conditions.contains(.diabetes) {
                                if let glucose = viewModel.vitals.latestGlucose {
                                    VitalCard(
                                        icon: "drop.fill",
                                        title: "Blood Glucose",
                                        value: "\(glucose.glucoseMgDl)",
                                        unit: "mg/dL",
                                        subLabel: "\(glucose.sampleType.displayName) · \(NivaraDate.relative(glucose.date))",
                                        status: viewModel.latestGlucoseStatus
                                    )
                                } else {
                                    emptyVitalCard(icon: "drop.fill", title: "Blood Glucose")
                                }
                            }
                        }

                        if let hba1c = viewModel.vitals.latestHbA1c, let tier = profile.hba1cTier {
                            VitalCard(
                                icon: "testtube.2",
                                title: "HbA1c",
                                value: String(format: "%.1f", hba1c.value),
                                unit: "%",
                                subLabel: "Your target: \(tier.targetLabel)",
                                status: nil
                            )
                        }
                    }

                    if let latestGoal = profile.smartGoals.first {
                        goalPreview(latestGoal)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hi, \(profile.name.components(separatedBy: " ").first ?? profile.name)")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.conditions.map(\.rawValue).joined(separator: " + "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Cared for by \(profile.physicianName)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch viewModel.bleManager.state {
        case .connected(let name):
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("Connected to \(name)")
                Spacer()
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(NivaraColor.normal)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(NivaraColor.normalBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        default:
            NavigationLink {
                DeviceConnectionView()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Connect your BP cuff or glucose meter")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(NivaraColor.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(NivaraColor.navy.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func emptyVitalCard(icon: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("No reading yet")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func goalPreview(_ goal: SmartGoal) -> some View {
        NavigationLink {
            CareTeamView()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Your goal", systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    PillLabel(text: goal.status.rawValue, color: goal.status.color, background: goal.status.color.opacity(0.15))
                }
                Text(goal.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView().environmentObject(PatientViewModel())
}
