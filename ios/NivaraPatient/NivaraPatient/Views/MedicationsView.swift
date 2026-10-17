import SwiftUI

/// Every current medication in large type, regardless of which condition
/// it's for — a patient managing both hypertension and diabetes takes them
/// all together, so hiding half the list by disease silo would be actively
/// misleading. A "Recent Changes" history sits right underneath so
/// patients can see what's different without hunting for it.
struct MedicationsView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore

    private var profile: PatientProfile { viewModel.profile }

    // Live Supabase data (set once refreshMedications() confirms a real
    // registration exists) takes priority over the bundled demo profile —
    // see PatientViewModel.refreshMedications's doc comment.
    private var currentMedications: [Medication] {
        viewModel.liveMedications ?? profile.medications
    }

    private var recentChanges: [MedicationChange] {
        (viewModel.liveMedicationHistory ?? profile.medicationHistory).sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageTitle(text: onboarding.t("medications_page_title"))
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
        .task {
            await viewModel.refreshMedications()
        }
        .refreshable {
            await viewModel.refreshMedications()
        }
    }

    private var currentMedicationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(onboarding.t("medications_your_medications"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)

            if currentMedications.isEmpty {
                Text(onboarding.t("medications_none_on_file"))
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
            }

            ForEach(currentMedications) { med in
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

            Text(onboarding.t("medications_prescribed_by", profile.physicianName))
                .font(.caption2)
                .foregroundStyle(NivaraColor.textSecondary)
        }
        .nivaraCard()
    }

    private var recentChangesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(onboarding.t("medications_recent_changes"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NivaraColor.textSecondary)

            if recentChanges.isEmpty {
                Text(onboarding.t("medications_no_changes_logged"))
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
    MedicationsView()
        .environmentObject(PatientViewModel())
        .environmentObject(OnboardingStore())
}
