import SwiftUI

struct BPHistoryListView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore

    var body: some View {
        List {
            ForEach(Array(viewModel.vitals.bpReadings.reversed())) { reading in
                HStack {
                    Text(NivaraDate.shortWithTime.string(from: reading.date))
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    Text(onboarding.t("health_bp_value", reading.systolic, reading.diastolic))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    if let pulse = reading.pulse {
                        PillLabel(text: onboarding.t("health_bpm", pulse))
                    }
                }
                .listRowBackground(NivaraColor.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NivaraColor.cream)
        .navigationTitle(onboarding.t("health_blood_pressure"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BPHistoryListView()
            .environmentObject(PatientViewModel())
            .environmentObject(OnboardingStore())
    }
}
