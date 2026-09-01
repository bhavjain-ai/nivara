import SwiftUI

/// Presents both consent documents (informed consent + data privacy) as
/// summary cards with a "Read full consent" link to the complete text, each
/// requiring its own explicit acceptance — mirrors the two separate paper
/// forms this replaces rather than collapsing them into one blanket
/// checkbox.
struct OnboardingConsentView: View {
    @EnvironmentObject private var onboarding: OnboardingStore
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showingInformedConsent = false
    @State private var showingPrivacyConsent = false

    var body: some View {
        OnboardingScaffold(
            title: "Your consent",
            subtitle: "Please review and accept both before we set up your device.",
            step: 2,
            totalSteps: 3,
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 16) {
                consentCard(
                    title: ConsentDocuments.informedConsentTitle,
                    summary: ConsentDocuments.informedConsentSummary,
                    isAccepted: $onboarding.acceptedInformedConsent,
                    showFullText: { showingInformedConsent = true }
                )
                consentCard(
                    title: ConsentDocuments.privacyConsentTitle,
                    summary: ConsentDocuments.privacyConsentSummary,
                    isAccepted: $onboarding.acceptedPrivacyConsent,
                    showFullText: { showingPrivacyConsent = true }
                )
                familyAccessCard
            }
        } footer: {
            OnboardingPrimaryButton(title: "I Agree — Next", enabled: onboarding.canProceedPastConsent, action: onNext)
        }
        .sheet(isPresented: $showingInformedConsent) {
            ConsentDocumentSheet(title: ConsentDocuments.informedConsentTitle, sections: ConsentDocuments.informedConsentSections)
        }
        .sheet(isPresented: $showingPrivacyConsent) {
            ConsentDocumentSheet(title: ConsentDocuments.privacyConsentTitle, sections: ConsentDocuments.privacyConsentSections)
        }
    }

    private func consentCard(title: String, summary: String, isAccepted: Binding<Bool>, showFullText: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NivaraColor.textPrimary)
            Text(summary)
                .font(.caption)
                .foregroundStyle(NivaraColor.textSecondary)
            Button(action: showFullText) {
                Text("Read full consent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.forestGreen)
            }
            .buttonStyle(.plain)

            Toggle(isOn: isAccepted) {
                Text("I have read and agree to this consent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NivaraColor.textPrimary)
            }
            .tint(NivaraColor.forestGreen)
        }
        .padding(14)
        .background(NivaraColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NivaraColor.border))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Mirrors the source document's Section 4 (Family Access): an optional,
    /// separately-revocable opt-in, not bundled into the two required
    /// consents above.
    private var familyAccessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $onboarding.shareWithFamilyMember) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share health trends with a family member")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NivaraColor.textPrimary)
                    Text("Optional — you can change this anytime from Contact Us.")
                        .font(.caption2)
                        .foregroundStyle(NivaraColor.textSecondary)
                }
            }
            .tint(NivaraColor.forestGreen)

            if onboarding.shareWithFamilyMember {
                TextField("Family member's name", text: $onboarding.familyMemberName)
                    .padding(10)
                    .background(NivaraColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Relationship (e.g. spouse, son)", text: $onboarding.familyMemberRelationship)
                    .padding(10)
                    .background(NivaraColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(NivaraColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NivaraColor.border))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    OnboardingConsentView(onNext: {}, onBack: {})
        .environmentObject(OnboardingStore())
}
