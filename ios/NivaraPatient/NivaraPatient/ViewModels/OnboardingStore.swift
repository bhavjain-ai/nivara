import Foundation
import Combine

/// Drives whether the app shows the guided first-run setup flow or goes
/// straight to the main app, plus the handful of fields that flow collects.
/// Persisted to UserDefaults directly (simple key-value state, unlike
/// VitalsStore's JSON history files) so it survives relaunch without a
/// backend.
final class OnboardingStore: ObservableObject {
    @Published var isComplete: Bool {
        didSet { defaults.set(isComplete, forKey: Keys.isComplete) }
    }
    @Published var firstName: String {
        didSet { defaults.set(firstName, forKey: Keys.firstName) }
    }
    @Published var lastName: String {
        didSet { defaults.set(lastName, forKey: Keys.lastName) }
    }
    @Published var dateOfBirth: Date? {
        didSet { defaults.set(dateOfBirth, forKey: Keys.dateOfBirth) }
    }
    @Published var acceptedInformedConsent: Bool {
        didSet { defaults.set(acceptedInformedConsent, forKey: Keys.acceptedInformedConsent) }
    }
    @Published var acceptedPrivacyConsent: Bool {
        didSet { defaults.set(acceptedPrivacyConsent, forKey: Keys.acceptedPrivacyConsent) }
    }
    @Published var shareWithFamilyMember: Bool {
        didSet { defaults.set(shareWithFamilyMember, forKey: Keys.shareWithFamilyMember) }
    }
    @Published var familyMemberName: String {
        didSet { defaults.set(familyMemberName, forKey: Keys.familyMemberName) }
    }
    @Published var familyMemberRelationship: String {
        didSet { defaults.set(familyMemberRelationship, forKey: Keys.familyMemberRelationship) }
    }
    @Published var familyMemberPhone: String {
        didSet { defaults.set(familyMemberPhone, forKey: Keys.familyMemberPhone) }
    }

    /// Both consent documents must be explicitly accepted before device
    /// setup — mirrors the two separate paper forms this replaces, which
    /// each require their own signature. If the patient opts into family
    /// sharing, a name and phone number are required too — an opt-in the
    /// care team can't act on without a way to actually reach that person
    /// isn't much of an opt-in.
    var canProceedPastConsent: Bool {
        guard acceptedInformedConsent && acceptedPrivacyConsent else { return false }
        if shareWithFamilyMember {
            return !familyMemberName.trimmingCharacters(in: .whitespaces).isEmpty &&
                !familyMemberPhone.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let isComplete = "onboarding.isComplete"
        static let firstName = "onboarding.firstName"
        static let lastName = "onboarding.lastName"
        static let dateOfBirth = "onboarding.dateOfBirth"
        static let acceptedInformedConsent = "onboarding.acceptedInformedConsent"
        static let acceptedPrivacyConsent = "onboarding.acceptedPrivacyConsent"
        static let shareWithFamilyMember = "onboarding.shareWithFamilyMember"
        static let familyMemberName = "onboarding.familyMemberName"
        static let familyMemberRelationship = "onboarding.familyMemberRelationship"
        static let familyMemberPhone = "onboarding.familyMemberPhone"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isComplete = defaults.bool(forKey: Keys.isComplete)
        firstName = defaults.string(forKey: Keys.firstName) ?? ""
        lastName = defaults.string(forKey: Keys.lastName) ?? ""
        dateOfBirth = defaults.object(forKey: Keys.dateOfBirth) as? Date
        acceptedInformedConsent = defaults.bool(forKey: Keys.acceptedInformedConsent)
        acceptedPrivacyConsent = defaults.bool(forKey: Keys.acceptedPrivacyConsent)
        shareWithFamilyMember = defaults.bool(forKey: Keys.shareWithFamilyMember)
        familyMemberName = defaults.string(forKey: Keys.familyMemberName) ?? ""
        familyMemberRelationship = defaults.string(forKey: Keys.familyMemberRelationship) ?? ""
        familyMemberPhone = defaults.string(forKey: Keys.familyMemberPhone) ?? ""
    }

    func markComplete() {
        isComplete = true
    }
}
