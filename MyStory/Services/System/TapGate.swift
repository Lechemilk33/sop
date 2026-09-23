import Foundation

/// Ignores taps that come too quickly after the previous one, anywhere in the
/// app. A double tap on "Tell a story" must not also press "Start talking" on
/// the next screen, and a shaky second tap must never do something twice.
@MainActor
final class TapGate {
    static let shared = TapGate()

    /// Minimum time between two accepted taps.
    let interval: TimeInterval

    private var lastAccepted: Date = .distantPast

    init(interval: TimeInterval = 0.6) {
        self.interval = interval
    }

    /// Returns `true` and records the tap if enough time has passed.
    func allow(at now: Date = Date()) -> Bool {
        guard now.timeIntervalSince(lastAccepted) >= interval else { return false }
        lastAccepted = now
        return true
    }
}

/// Runs a tap's action through the tap gate, with a light haptic tap.
@MainActor
enum TapGuard {
    static func perform(_ action: () -> Void) {
        guard TapGate.shared.allow() else { return }
        Haptics.tap()
        action()
    }
}
