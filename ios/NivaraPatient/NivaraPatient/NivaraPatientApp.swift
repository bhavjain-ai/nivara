import SwiftUI

@main
struct NivaraPatientApp: App {
    // Owned at the app level (not inside RootView/OnboardingFlowView) so the
    // same PatientViewModel — and the same BLEManager/BLE connection —
    // carries straight through from onboarding's device-setup step into the
    // main app, rather than reconnecting from scratch.
    @StateObject private var onboarding = OnboardingStore()
    @StateObject private var viewModel = PatientViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarding.isComplete {
                    RootView()
                } else {
                    OnboardingFlowView()
                }
            }
            .environmentObject(onboarding)
            .environmentObject(viewModel)
            // Affects system-drawn chrome (DatePicker, etc.) — the app's own
            // text is translated separately via OnboardingStore.t(_:),
            // since relying on this alone would require a full Xcode String
            // Catalog + compiler to verify correctly, which isn't available
            // in this environment (see Translations.swift's doc comment).
            .environment(\.locale, onboarding.selectedLanguage.locale)
        }
    }
}
