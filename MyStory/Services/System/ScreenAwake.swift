import UIKit

/// Keeps the screen on while something is under way that he's watching or
/// the family is waiting for: a story being told, a story playing (he sees
/// who's in it and can read along), or a copy being saved. Each reason is
/// kept separately, so one ending never lets the screen sleep while another
/// is still going.
@MainActor
enum ScreenAwake {
    enum Reason: Hashable {
        case recording
        case playing
        case savingCopy
    }

    private static var reasons: Set<Reason> = []

    static func set(_ reason: Reason, _ isOn: Bool) {
        if isOn {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }
        let keepAwake = !reasons.isEmpty
        if UIApplication.shared.isIdleTimerDisabled != keepAwake {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
    }
}
