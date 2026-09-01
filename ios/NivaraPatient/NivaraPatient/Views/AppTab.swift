import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case myHealth = "My Health"
    case careTeam = "Care Team"
    case contactUs = "Contact Us"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .myHealth: return "heart.text.square.fill"
        case .careTeam: return "person.2.fill"
        case .contactUs: return "phone.fill"
        }
    }
}
