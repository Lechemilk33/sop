import Foundation
import SwiftData

/// What the player should play.
enum PlaybackRequest {
    case single(Story)
    /// "Play them all": one after another, in order.
    case queue([Story], startIndex: Int)
    /// "Play me a story": a story he hasn't heard in a while.
    case surprise
}

/// Picks a story for "Play me a story": mostly ones he hasn't heard lately,
/// with a little chance so it doesn't feel predictable. Stories whose length
/// is known come first; one whose length couldn't be read still plays if
/// it's all there is. With only one story, it's that one again.
@MainActor
enum SurprisePicker {
    static func pick(in context: ModelContext, excluding excluded: Story? = nil) -> Story? {
        let others = ((try? context.fetch(FetchDescriptor<Story>())) ?? [])
            .filter { $0.persistentModelID != excluded?.persistentModelID }
        let timed = others.filter { $0.duration > 0 }
        let stories = timed.isEmpty ? others : timed
        guard !stories.isEmpty else { return excluded }
        let sorted = stories.sorted { ($0.lastPlayedAt ?? .distantPast) < ($1.lastPlayedAt ?? .distantPast) }
        let shortlist = sorted.prefix(max(1, min(5, sorted.count / 3 + 1)))
        return shortlist.randomElement()
    }
}
