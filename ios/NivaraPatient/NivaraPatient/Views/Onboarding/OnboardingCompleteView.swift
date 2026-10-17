import SwiftUI

/// Final onboarding screen. When device setup captured a real reading
/// (`viewModel.pendingMealTimingConfirmation`, set by a genuine BLE glucose
/// reading — see PatientViewModel), this immediately acknowledges it by
/// value and status, dynamically, rather than a generic "you're done"
/// message. The reading's fasting/post-meal tag isn't asked yet at this
/// point (that happens via the same meal-timing sheet moments later, once
/// RootView mounts), so the message is phrased type-agnostically.
struct OnboardingCompleteView: View {
    @EnvironmentObject private var viewModel: PatientViewModel
    @EnvironmentObject private var onboarding: OnboardingStore
    let onDone: () -> Void

    private var firstReading: GlucoseReading? { viewModel.pendingMealTimingConfirmation }

    private var resultMessage: String? {
        guard let reading = firstReading, let tier = viewModel.profile.hba1cTier else { return nil }
        let targets = ClinicalGuidelines.glucoseTargets(forTier: tier.tier)
        let status = ClinicalGuidelines.analyzeGlucose(glucose: reading.glucoseMgDl, sampleType: reading.sampleType, targets: targets)
        let rangeText: String
        switch status.level {
        case .normal: rangeText = onboarding.t("complete_range_normal")
        case .warning: rangeText = onboarding.t("complete_range_warning")
        case .critical: rangeText = onboarding.t("complete_range_critical")
        }
        return onboarding.t("complete_first_reading_message", reading.glucoseMgDl, rangeText)
    }

    var body: some View {
        ZStack {
            NivaraColor.cream.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(NivaraColor.forestGreen)

                Text(onboarding.t("complete_title"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(NivaraColor.textPrimary)

                Text(resultMessage ?? fallbackMessage)
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                OnboardingPrimaryButton(title: onboarding.t("complete_go_to_nivara")) {
                    // Fire-and-forget: registration is best-effort (see
                    // SupabaseService.registerPatient) and must never delay
                    // or block getting into the main app, whether that's
                    // because there's no network right now or because no
                    // Supabase project has been configured at all yet.
                    Task {
                        await SupabaseService.registerPatient(
                            onboarding: onboarding,
                            demoProfile: viewModel.profile,
                            clinicId: onboarding.selectedClinicId
                        )
                    }
                    onDone()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private var fallbackMessage: String {
        let name = onboarding.firstName.isEmpty ? onboarding.t("complete_fallback_name") : onboarding.firstName
        return onboarding.t("complete_fallback_message", name)
    }
}

#Preview {
    OnboardingCompleteView(onDone: {})
        .environmentObject(PatientViewModel())
        .environmentObject(OnboardingStore())
}
