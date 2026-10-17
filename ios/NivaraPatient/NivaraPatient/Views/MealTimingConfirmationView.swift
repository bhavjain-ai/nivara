import SwiftUI

/// Presented right after a glucose BLE reading is saved. Meters don't
/// reliably signal fasting vs. post-meal, so rather than only offering a
/// passive correction later (see `MyHealthView.retagRow`), this asks the
/// patient directly while the context is fresh — better-quality tagging up
/// front means the target range it's judged against is right the first time.
struct MealTimingConfirmationView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore
    let reading: GlucoseReading

    var body: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(NivaraColor.border)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(reading.glucoseMgDl)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(NivaraColor.textPrimary)
                    Text(onboarding.t("health_unit_mgdl"))
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
                Text(onboarding.t("mealtiming_question"))
                    .font(.headline)
                    .foregroundStyle(NivaraColor.textPrimary)
                Text(onboarding.t("mealtiming_explanation"))
                    .font(.caption)
                    .foregroundStyle(NivaraColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                timingButton(
                    title: onboarding.t("mealtiming_more_than_2h"),
                    subtitle: onboarding.t("mealtiming_fasting_subtitle"),
                    sampleType: .fasting
                )
                timingButton(
                    title: onboarding.t("mealtiming_less_than_2h"),
                    subtitle: onboarding.t("mealtiming_postmeal_subtitle"),
                    sampleType: .postMeal
                )
            }
            .padding(.horizontal)

            Button {
                viewModel.dismissMealTimingConfirmation()
            } label: {
                Text(onboarding.t("mealtiming_skip"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .background(NivaraColor.cream)
    }

    private func timingButton(title: String, subtitle: String, sampleType: GlucoseSampleType) -> some View {
        Button {
            viewModel.confirmMealTiming(sampleType)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NivaraColor.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(NivaraColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NivaraColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NivaraColor.border))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MealTimingConfirmationView(
        reading: GlucoseReading(date: Date(), glucoseMgDl: 128, sampleType: .fasting, source: .demo)
    )
    .environmentObject(PatientViewModel())
    .environmentObject(OnboardingStore())
}
