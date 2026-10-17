import Foundation

/// The 5 languages this pilot supports, picked once at enrollment (see
/// OnboardingLanguageView) and persisted on OnboardingStore. Drives both
/// this app's own translated UI text (OnboardingStore.t, backed by
/// Translations.swift) and the system locale applied at the app root
/// (NivaraPatientApp), which affects system-drawn chrome like DatePicker.
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case hindi = "hi"
    case telugu = "te"
    case kannada = "kn"
    case tamil = "ta"

    var id: String { rawValue }

    /// Shown in its own language on the picker itself, so a patient can
    /// recognize their language even while the picker is still displaying
    /// in whatever language was selected last (or English, by default).
    var displayName: String {
        switch self {
        case .english: return "English"
        case .hindi: return "हिन्दी"
        case .telugu: return "తెలుగు"
        case .kannada: return "ಕನ್ನಡ"
        case .tamil: return "தமிழ்"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}
