import Foundation

/// "Good morning, Dave". Pure and testable.
enum Greeting {
    static func text(for date: Date, name: String, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let salutation: String
        switch hour {
        case 5..<12: salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        case 17..<22: salutation = "Good evening"
        default: salutation = "Hello"
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? salutation : "\(salutation), \(trimmed)"
    }
}

/// Durations in words he can read at a glance.
enum DurationText {
    /// "0:07", "4:05", "1:02:03".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.isFinite ? seconds.rounded(.down) : 0))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// "Under a minute", "1 min", "4 min", "1 hr 5 min".
    static func spoken(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 60 else { return "Under a minute" }
        let totalMinutes = Int((seconds / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(totalMinutes) min" }
        return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
    }
}

/// Dates written out in full, never as numbers only.
enum DayText {
    /// "Tuesday, September 23".
    static func full(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        formatter(template: "EEEEMMMMd", locale: locale, timeZone: timeZone).string(from: date)
    }

    /// "September 12, 2026".
    static func long(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        formatter(template: "MMMMdyyyy", locale: locale, timeZone: timeZone).string(from: date)
    }

    /// "Told today", "Told yesterday", "Told Sep 12".
    static func toldShort(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Told today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Told yesterday"
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let template = sameYear ? "MMMd" : "MMMdyyyy"
        return "Told " + formatter(template: template, locale: calendar.locale ?? .current, timeZone: calendar.timeZone).string(from: date)
    }

    /// "Told by you today", "Told by you on September 12".
    static func toldByYou(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Told by you today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Told by you yesterday"
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let template = sameYear ? "MMMMd" : "MMMMdyyyy"
        return "Told by you on " + formatter(template: template, locale: calendar.locale ?? .current, timeZone: calendar.timeZone).string(from: date)
    }

    /// "2026-09-12", for file names.
    static func isoDay(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func formatter(template: String, locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

/// "1 story", "14 stories", "No stories yet".
enum StoryCountText {
    static func text(_ count: Int) -> String {
        switch count {
        case ..<1: return "No stories yet"
        case 1: return "1 story"
        default: return "\(count) stories"
        }
    }
}
