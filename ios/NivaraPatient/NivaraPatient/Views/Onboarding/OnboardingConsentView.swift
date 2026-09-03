import SwiftUI

/// Presents both consent documents (informed consent + data privacy) as
/// summary cards with a "Read full consent" link to the complete text, each
/// requiring its own explicit acceptance — mirrors the two separate paper
/// forms this replaces rather than collapsing them into one blanket
/// checkbox.
///
/// Each document's "I agree" toggle stays disabled until the patient has
/// scrolled to the bottom of that document's full text (see
/// ConsentDocumentSheet's `onReachedBottom`) — this is checked fresh every
/// time this screen appears (including navigating back to it), so a patient
/// can't toggle agreement without actually having scrolled through in this
/// visit.
struct OnboardingConsentView: View {
    @EnvironmentObject private var onboarding: OnboardingStore
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showingInformedConsent = false
    @State private var showingPrivacyConsent = false
    @State private var hasReadInformedConsent = false
    @State private var hasReadPrivacyConsent = false

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
                    hasRead: hasReadInformedConsent,
                    isAccepted: $onboarding.acceptedInformedConsent,
                    showFullText: { showingInformedConsent = true }
                )
                consentCard(
                    title: ConsentDocuments.privacyConsentTitle,
                    summary: ConsentDocuments.privacyConsentSummary,
                    hasRead: hasReadPrivacyConsent,
                    isAccepted: $onboarding.acceptedPrivacyConsent,
                    showFullText: { showingPrivacyConsent = true }
                )
                familyAccessCard
            }
        } footer: {
            OnboardingPrimaryButton(title: "I Agree — Next", enabled: onboarding.canProceedPastConsent, action: onNext)
        }
        .onAppear {
            // Force a fresh read-and-accept every time this screen is
            // (re)entered, including via the back button from device setup
            // — a previously-granted acceptance shouldn't silently carry
            // over without the patient having scrolled through again now.
            onboarding.acceptedInformedConsent = false
            onboarding.acceptedPrivacyConsent = false
            hasReadInformedConsent = false
            hasReadPrivacyConsent = false
        }
        .sheet(isPresented: $showingInformedConsent) {
            ConsentDocumentSheet(
                title: ConsentDocuments.informedConsentTitle,
                sections: ConsentDocuments.informedConsentSections,
                onReachedBottom: { hasReadInformedConsent = true }
            )
        }
        .sheet(isPresented: $showingPrivacyConsent) {
            ConsentDocumentSheet(
                title: ConsentDocuments.privacyConsentTitle,
                sections: ConsentDocuments.privacyConsentSections,
                onReachedBottom: { hasReadPrivacyConsent = true }
            )
        }
    }

    private func consentCard(title: String, summary: String, hasRead: Bool, isAccepted: Binding<Bool>, showFullText: @escaping () -> Void) -> some View {
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

            HStack(spacing: 6) {
                Image(systemName: hasRead ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundStyle(hasRead ? NivaraColor.forestGreen : NivaraColor.textSecondary)
                Text(hasRead ? "Reviewed — you can agree below" : "Scroll to the end of the full consent to continue")
                    .font(.caption2)
                    .foregroundStyle(hasRead ? NivaraColor.forestGreen : NivaraColor.textSecondary)
            }

            Toggle(isOn: isAccepted) {
                Text("I have read and agree to this consent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hasRead ? NivaraColor.textPrimary : NivaraColor.textSecondary)
            }
            .tint(NivaraColor.forestGreen)
            .disabled(!hasRead)
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
                TextField("Phone number", text: $onboarding.familyMemberPhone)
                    .keyboardType(.phonePad)
                    .padding(10)
                    .background(NivaraColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("So your care team has a way to reach them if needed.")
                    .font(.caption2)
                    .foregroundStyle(NivaraColor.textSecondary)
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
