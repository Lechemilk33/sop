import UIKit

/// Gentle haptic feedback. Research on touchscreens for people with dementia
/// found immediate feedback through more than one sense helps, so every tap
/// and every save is felt as well as seen.
@MainActor
enum Haptics {
    static func tap() {
        guard let window else { return }
        UIImpactFeedbackGenerator(style: .light, view: window).impactOccurred()
    }

    static func success() {
        guard let window else { return }
        UINotificationFeedbackGenerator(view: window).notificationOccurred(.success)
    }

    /// Feedback generators belong to a view; the app's window will do.
    private static var window: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
    }
}
