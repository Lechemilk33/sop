import Foundation
import Observation

/// Settings the family chooses. Stored on this iPhone.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let personName = "personName"
        static let textSize = "textSize"
        static let hasCompletedSetup = "hasCompletedSetup"
        static let readQuestionsAutomatically = "readQuestionsAutomatically"
        static let lastCopySavedAt = "lastCopySavedAt"
    }

    private let defaults: UserDefaults

    /// The name the app greets him by, e.g. "Dave".
    var personName: String {
        didSet { defaults.set(personName, forKey: Key.personName) }
    }

    var textSize: TextSize {
        didSet { defaults.set(textSize.rawValue, forKey: Key.textSize) }
    }

    var hasCompletedSetup: Bool {
        didSet { defaults.set(hasCompletedSetup, forKey: Key.hasCompletedSetup) }
    }

    /// Read each new question out loud without a tap.
    var readQuestionsAutomatically: Bool {
        didSet { defaults.set(readQuestionsAutomatically, forKey: Key.readQuestionsAutomatically) }
    }

    var lastCopySavedAt: Date? {
        didSet { defaults.set(lastCopySavedAt, forKey: Key.lastCopySavedAt) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        personName = defaults.string(forKey: Key.personName) ?? ""
        textSize = TextSize(rawValue: defaults.string(forKey: Key.textSize) ?? "") ?? .standard
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
        readQuestionsAutomatically = defaults.bool(forKey: Key.readQuestionsAutomatically)
        lastCopySavedAt = defaults.object(forKey: Key.lastCopySavedAt) as? Date
    }

    /// His name for sentences like "Thank you, Dave." Falls back gracefully.
    var displayName: String {
        let trimmed = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }
}
