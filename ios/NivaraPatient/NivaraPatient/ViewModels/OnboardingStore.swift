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
    /// Picked on the very first onboarding screen (OnboardingLanguageView)
    /// and used by `t(_:)`/`t(_:_:)` below for every translated string in
    /// the app — see Translations.swift.
    @Published var selectedLanguage: AppLanguage {
        didSet { defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage) }
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
    /// Which clinic this patient's join code resolved to during onboarding
    /// (see OnboardingBasicInfoView, SupabaseService.resolveClinic). Nil if
    /// Supabase isn't configured or no code has resolved yet —
    /// registerPatient then leaves patients.clinic_id null.
    @Published var selectedClinicId: UUID? {
        didSet { defaults.set(selectedClinicId?.uuidString, forKey: Keys.selectedClinicId) }
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
        static let selectedLanguage = "onboarding.selectedLanguage"
        static let firstName = "onboarding.firstName"
        static let lastName = "onboarding.lastName"
        static let dateOfBirth = "onboarding.dateOfBirth"
        static let selectedClinicId = "onboarding.selectedClinicId"
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
        selectedLanguage = (defaults.string(forKey: Keys.selectedLanguage)).flatMap(AppLanguage.init) ?? .english
        firstName = defaults.string(forKey: Keys.firstName) ?? ""
        lastName = defaults.string(forKey: Keys.lastName) ?? ""
        dateOfBirth = defaults.object(forKey: Keys.dateOfBirth) as? Date
        selectedClinicId = (defaults.string(forKey: Keys.selectedClinicId)).flatMap(UUID.init)
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

    /// Looks up `key` in Translations.swift for `selectedLanguage`, falling
    /// back to English, then to the key itself if even English is missing
    /// (so a typo'd/not-yet-translated key fails visibly instead of
    /// crashing — easy to spot in testing, never a runtime crash for a
    /// patient).
    func t(_ key: String) -> String {
        Translations.table[key]?[selectedLanguage] ?? Translations.table[key]?[.english] ?? key
    }

    /// Same lookup, for a template string containing %@ placeholders (e.g.
    /// "%@ · %@" for "dose · frequency") — use this instead of raw Swift
    /// string interpolation so formatting stays predictable across
    /// languages without relying on SwiftUI's own (unverifiable without a
    /// compiler) interpolated-LocalizedStringKey matching.
    func t(_ key: String, _ args: CVarArg...) -> String {
        let template = Translations.table[key]?[selectedLanguage] ?? Translations.table[key]?[.english] ?? key
        return String(format: template, arguments: args)
    }
}
