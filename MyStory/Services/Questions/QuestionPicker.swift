import Foundation

/// A lightweight snapshot of a question, so choosing the next one is pure,
/// fast and unit-tested.
struct QuestionCandidate: Equatable {
    let id: UUID
    /// Lower is asked sooner (recent decades first).
    let chapterPriority: Int
    let isFamilyQuestion: Bool
    let isFreeTalk: Bool
    let answerCount: Int
    let timesShown: Int
    let lastShownAt: Date?
    let createdAt: Date
}

/// Chooses the next question to ask.
///
/// 1. Questions the family added and he hasn't answered come first.
/// 2. Now and then, "What's on your mind today?" (never twice in a row).
/// 3. Then built-in questions he hasn't answered, recent decades first,
///    least-asked first.
/// 4. When everything has been answered, the ones asked longest ago.
///
/// A little randomness among the best few keeps it from feeling repetitive.
struct QuestionPicker {
    /// How many of the best candidates to choose between.
    var shortlistSize = 4
    /// Roughly one in this many picks is the free-talk question.
    var freeTalkEvery = 6

    func pick<G: RandomNumberGenerator>(
        from candidates: [QuestionCandidate],
        excluding excluded: Set<UUID>,
        allowFreeTalk: Bool,
        using generator: inout G
    ) -> QuestionCandidate? {
        let available = candidates.filter { !excluded.contains($0.id) }
        guard !available.isEmpty else { return candidates.first }

        let family = available
            .filter { $0.isFamilyQuestion && $0.answerCount == 0 && !$0.isFreeTalk }
            .sorted { $0.createdAt < $1.createdAt }
        if !family.isEmpty {
            return choose(from: Array(family.prefix(2)), using: &generator)
        }

        if allowFreeTalk,
           let freeTalk = available.first(where: { $0.isFreeTalk }),
           Int.random(in: 0..<max(1, freeTalkEvery), using: &generator) == 0 {
            return freeTalk
        }

        let unanswered = available
            .filter { $0.answerCount == 0 && !$0.isFreeTalk }
            .sorted { lhs, rhs in
                if lhs.timesShown != rhs.timesShown { return lhs.timesShown < rhs.timesShown }
                if lhs.chapterPriority != rhs.chapterPriority { return lhs.chapterPriority < rhs.chapterPriority }
                return lhs.createdAt < rhs.createdAt
            }
        if !unanswered.isEmpty {
            let bestShown = unanswered[0].timesShown
            let bestPriority = unanswered[0].chapterPriority
            let shortlist = unanswered.filter { $0.timesShown == bestShown && $0.chapterPriority == bestPriority }
            return choose(from: Array(shortlist.prefix(shortlistSize)), using: &generator)
        }

        let leastRecent = available
            .filter { !$0.isFreeTalk || allowFreeTalk }
            .sorted { ($0.lastShownAt ?? .distantPast) < ($1.lastShownAt ?? .distantPast) }
        return choose(from: Array(leastRecent.prefix(shortlistSize)), using: &generator) ?? available.first
    }

    private func choose<G: RandomNumberGenerator>(from list: [QuestionCandidate], using generator: inout G) -> QuestionCandidate? {
        guard !list.isEmpty else { return nil }
        return list[Int.random(in: 0..<list.count, using: &generator)]
    }
}

/// Joins transcription pieces into readable text with single spaces.
enum TranscriptJoiner {
    static func join(_ pieces: [String]) -> String {
        var result = ""
        for piece in pieces {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if result.isEmpty {
                result = trimmed
            } else if let first = trimmed.first, ",.;:!?".contains(first) {
                result += trimmed
            } else {
                result += " " + trimmed
            }
        }
        return result
    }
}
