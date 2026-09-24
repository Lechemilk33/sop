import UIKit

/// A little extra time to finish something important, like saving a story
/// or starting the next one, if the phone is locked meanwhile. When the time
/// runs out, `onExpire` runs first and then the activity ends by itself, so
/// the system never has to stop the app.
@MainActor
final class BackgroundActivity {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(_ name: String, onExpire: (@MainActor @Sendable () -> Void)? = nil) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [self] in
            onExpire?()
            end()
        }
    }

    /// Hands the time back. Safe to call more than once.
    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
