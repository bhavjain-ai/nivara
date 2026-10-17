import Foundation

enum NivaraDate {
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static let shortWithTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, h:mm a"
        return f
    }()

    static let chartAxis: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d/M"
        return f
    }()

    static func relative(_ date: Date, language: AppLanguage = .english) -> String {
        func t(_ key: String) -> String {
            Translations.table[key]?[language] ?? Translations.table[key]?[.english] ?? key
        }
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return t("time_just_now") }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return String(format: t(minutes == 1 ? "time_minute_ago" : "time_minutes_ago"), minutes) }
        let hours = minutes / 60
        if hours < 24 { return String(format: t(hours == 1 ? "time_hour_ago" : "time_hours_ago"), hours) }
        let days = hours / 24
        return String(format: t(days == 1 ? "time_day_ago" : "time_days_ago"), days)
    }

    static func greeting(for date: Date = Date(), language: AppLanguage = .english) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let key: String
        switch hour {
        case 0..<12: key = "greeting_morning"
        case 12..<17: key = "greeting_afternoon"
        default: key = "greeting_evening"
        }
        return Translations.table[key]?[language] ?? Translations.table[key]?[.english] ?? key
    }
}
