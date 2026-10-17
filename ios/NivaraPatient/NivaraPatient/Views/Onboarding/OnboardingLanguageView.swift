import SwiftUI

/// Very first screen on a fresh install, before even the welcome screen —
/// everything after this (including the welcome screen itself) is shown in
/// whichever language is picked here. English is pre-selected so a patient
/// who doesn't need to change anything can just tap Continue.
struct OnboardingLanguageView: View {
    @EnvironmentObject private var onboarding: OnboardingStore
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            NivaraColor.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 32)

                VStack(spacing: 8) {
                    Text(onboarding.t("onboarding_language_title"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(NivaraColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(onboarding.t("onboarding_language_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(NivaraColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { language in
                        languageRow(language)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                Button(action: onContinue) {
                    Text(onboarding.t("common_continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NivaraColor.forestGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let isSelected = onboarding.selectedLanguage == language
        return Button {
            onboarding.selectedLanguage = language
        } label: {
            HStack {
                Text(language.displayName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(NivaraColor.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(NivaraColor.forestGreen)
                }
            }
            .padding(16)
            .background(NivaraColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? NivaraColor.forestGreen : NivaraColor.border, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingLanguageView(onContinue: {})
        .environmentObject(OnboardingStore())
}
