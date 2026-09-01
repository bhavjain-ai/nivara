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
        case .normal: rangeText = "within range"
        case .warning: rangeText = "a little outside your usual range"
        case .critical: rangeText = "outside your target range"
        }
        return "Thank you for taking your first measurement. Your blood glucose is \(reading.glucoseMgDl) mg/dL, which is \(rangeText). Great job!"
    }

    var body: some View {
        ZStack {
            NivaraColor.cream.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(NivaraColor.forestGreen)

                Text("You're all set!")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(NivaraColor.textPrimary)

                Text(resultMessage ?? fallbackMessage)
                    .font(.subheadline)
                    .foregroundStyle(NivaraColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                OnboardingPrimaryButton(title: "Go to Nivara", action: onDone)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
        }
    }

    private var fallbackMessage: String {
        let name = onboarding.firstName.isEmpty ? "there" : onboarding.firstName
        return "Welcome, \(name). You can connect your glucometer anytime from My Health."
    }
}

#Preview {
    OnboardingCompleteView(onDone: {})
        .environmentObject(PatientViewModel())
        .environmentObject(OnboardingStore())
}
