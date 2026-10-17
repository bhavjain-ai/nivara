import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case myHealth = "My Health"
    case medications = "Medications"
    case careTeam = "Care Team"
    case contactUs = "Contact Us"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .myHealth: return "heart.text.square.fill"
        case .medications: return "pills.fill"
        case .careTeam: return "person.2.fill"
        case .contactUs: return "phone.fill"
        }
    }

    /// Translated label for the side rail (see RootView) — kept separate
    /// from `rawValue`, which stays a stable English identifier (used for
    /// `id` and nowhere compared against user-visible text).
    func displayName(for language: AppLanguage) -> String {
        let key: String
        switch self {
        case .home: key = "tab_home"
        case .myHealth: key = "tab_my_health"
        case .medications: key = "tab_medications"
        case .careTeam: key = "tab_care_team"
        case .contactUs: key = "tab_contact_us"
        }
        return Translations.table[key]?[language] ?? Translations.table[key]?[.english] ?? key
    }
}
