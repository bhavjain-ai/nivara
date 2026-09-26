import SwiftUI

/// Every current medication in large type, regardless of which condition
/// it's for — a patient managing both hypertension and diabetes takes them
/// all together, so hiding half the list by disease silo would be actively
/// misleading. A "Recent Changes" history sits right underneath so
/// patients can see what's different without hunting for it.
struct MedicationsView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    private var recentChanges: [MedicationChange] {
        profile.medicationHistory.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageTitle(text: "Medications")
                        .padding(.top, 8)
                    currentMedicationsCard
                    recentChangesCard
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(NivaraColor.cream)
            .navigationBarHidden(true)
        }
    }

    private var currentMedicationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR MEDICATIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)

            if profile.medications.isEmpty {
                Text("No medications on file yet.")
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ForEach(profile.medications) { med in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(med.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(NivaraColor.textPrimary)
                        Spacer()
                        PillLabel(text: med.drugClass)
                    }
                    Text("\(med.dose) · \(med.frequency)")
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                .padding(.vertical, 6)
                Divider()
            }

            Text("Prescribed by \(profile.physicianName)")
                .font(.caption2)
                .foregroundStyle(NivaraColor.textSecondary)
        }
        .nivaraCard()
    }

    private var recentChangesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT CHANGES")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)

            if recentChanges.isEmpty {
                Text("No changes logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ForEach(recentChanges) { change in
                VStack(alignment: .leading, spacing: 2) {
                    Text(NivaraDate.short.string(from: change.date))
                        .font(.caption2)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Text(change.description)
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textPrimary)
                }
                .padding(.vertical, 4)
            }
        }
        .nivaraCard()
    }
}

#Preview {
    MedicationsView().environmentObject(PatientViewModel())
}
