import SwiftUI

/// Collects only what's needed to personalize the app and identify the
/// patient — deliberately short, per the guided-onboarding goal of minimal
/// friction before consent and device setup.
struct OnboardingBasicInfoView: View {
    @EnvironmentObject private var onboarding: OnboardingStore
    let onNext: () -> Void
    let onBack: () -> Void

    private var canContinue: Bool {
        !onboarding.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !onboarding.lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var defaultDateOfBirth: Date {
        Calendar.current.date(byAdding: .year, value: -45, to: Date()) ?? Date()
    }

    var body: some View {
        OnboardingScaffold(
            title: "Tell us about you",
            subtitle: "Enter your information just as it appears on your health insurance card or ID.",
            step: 1,
            totalSteps: 3,
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 20) {
                labeledField("First name") {
                    TextField("First name", text: $onboarding.firstName)
                        .textInputAutocapitalization(.words)
                }
                labeledField("Last name") {
                    TextField("Last name", text: $onboarding.lastName)
                        .textInputAutocapitalization(.words)
                }
                labeledField("Date of birth") {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { onboarding.dateOfBirth ?? defaultDateOfBirth },
                            set: { onboarding.dateOfBirth = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
            }
        } footer: {
            OnboardingPrimaryButton(title: "Next", enabled: canContinue, action: onNext)
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NivaraColor.textPrimary)
            content()
                .padding(14)
                .background(NivaraColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NivaraColor.border))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    OnboardingBasicInfoView(onNext: {}, onBack: {})
        .environmentObject(OnboardingStore())
}
