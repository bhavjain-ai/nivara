import SwiftUI

struct GlucoseHistoryListView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore

    var body: some View {
        List {
            ForEach(Array(viewModel.vitals.glucoseReadings.reversed())) { reading in
                HStack {
                    Text(NivaraDate.shortWithTime.string(from: reading.date))
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                    Spacer()
                    Text(onboarding.t("health_glucose_value", reading.glucoseMgDl))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    PillLabel(text: reading.sampleType.displayName)
                }
                .listRowBackground(NivaraColor.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NivaraColor.cream)
        .navigationTitle(onboarding.t("health_blood_glucose"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GlucoseHistoryListView()
            .environmentObject(PatientViewModel())
            .environmentObject(OnboardingStore())
    }
}
