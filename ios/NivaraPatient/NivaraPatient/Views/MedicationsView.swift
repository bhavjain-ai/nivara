import SwiftUI

/// Scoped to the Type 2 diabetes regimen, matching the initial patient
/// population — current medications in large type, with a "Recent Changes"
/// history right underneath so patients can see what's different without
/// hunting for it.
struct MedicationsView: View {
    @EnvironmentObject private var viewModel: PatientViewModel

    private var profile: PatientProfile { viewModel.profile }

    private var diabetesMedications: [Medication] {
        profile.medications.filter { $0.isDiabetesMedication }
    }

    private var diabetesChanges: [MedicationChange] {
        profile.medicationHistory
            .filter { $0.relatedCondition == .diabetes }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    currentMedicationsCard
                    recentChangesCard
                }
                .padding()
            }
            .background(NivaraColor.cream)
            .navigationTitle("Medications")
        }
    }

    private var currentMedicationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR DIABETES MEDICATIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)

            if diabetesMedications.isEmpty {
                Text("No diabetes medications on file yet.")
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ForEach(diabetesMedications) { med in
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

            if diabetesChanges.isEmpty {
                Text("No changes logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ForEach(diabetesChanges) { change in
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
