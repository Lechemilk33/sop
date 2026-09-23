import UIKit

/// Gentle haptic feedback. Research on touchscreens for people with dementia
/// found immediate feedback through more than one sense helps, so every tap
/// and every save is felt as well as seen.
@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() {
        impact.impactOccurred()
    }

    static func success() {
        notification.notificationOccurred(.success)
    }
}
