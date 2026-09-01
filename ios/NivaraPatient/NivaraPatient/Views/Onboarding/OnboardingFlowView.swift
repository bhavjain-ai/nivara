import SwiftUI

/// Top-level state machine for the first-run setup flow: welcome → basic
/// info → consent → guided device setup → completion. Shown by
/// NivaraPatientApp in place of RootView until `OnboardingStore.isComplete`.
struct OnboardingFlowView: View {
    @EnvironmentObject private var onboarding: OnboardingStore
    @State private var step: Step = .welcome

    private enum Step {
        case welcome, basicInfo, consent, deviceSetup, complete
    }

    var body: some View {
        Group {
            switch step {
            case .welcome:
                OnboardingWelcomeView(onContinue: { step = .basicInfo })
            case .basicInfo:
                OnboardingBasicInfoView(onNext: { step = .consent }, onBack: { step = .welcome })
            case .consent:
                OnboardingConsentView(onNext: { step = .deviceSetup }, onBack: { step = .basicInfo })
            case .deviceSetup:
                OnboardingDeviceSetupView(onBack: { step = .consent }, onFinished: { step = .complete })
            case .complete:
                OnboardingCompleteView(onDone: { onboarding.markComplete() })
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(OnboardingStore())
        .environmentObject(PatientViewModel())
}
