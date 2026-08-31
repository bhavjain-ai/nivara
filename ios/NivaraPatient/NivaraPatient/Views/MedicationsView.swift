import SwiftUI

struct MedicationsView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    var body: some View {
        NavigationStack {
            List {
                Section("Your Medications") {
                    ForEach(profile.medications) { med in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(med.name).fontWeight(.semibold)
                                Spacer()
                                PillLabel(text: med.drugClass)
                            }
                            Text("\(med.dose) · \(med.frequency)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Since \(NivaraDate.short.string(from: med.startDate))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    if let bpTarget = profile.bpTarget {
                        targetRow(icon: "heart.fill", title: "Blood Pressure Target", detail: bpTarget.label)
                    }
                    if let tier = profile.hba1cTier {
                        targetRow(icon: "testtube.2", title: "HbA1c Target", detail: "\(tier.targetLabel) — set for you based on your age, health history, and how long you've had diabetes")
                    }
                } header: {
                    Text("Your Personal Targets")
                } footer: {
                    Text("These targets are set by your physician and may be different from a general guideline — they're tailored to you.")
                }

                Section {
                    HStack {
                        Text("Physician")
                        Spacer()
                        Text(profile.physicianName).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Medications")
        }
    }

    private func targetRow(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MedicationsView().environmentObject(PatientViewModel())
}
