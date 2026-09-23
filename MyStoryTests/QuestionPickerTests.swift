import Foundation
import Testing
@testable import MyStory

/// A small, repeatable random number generator so tests are deterministic.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func candidate(
    priority: Int = 50,
    family: Bool = false,
    freeTalk: Bool = false,
    answers: Int = 0,
    shown: Int = 0,
    lastShown: Date? = nil,
    created: Date = Date(timeIntervalSince1970: 0)
) -> QuestionCandidate {
    QuestionCandidate(
        id: UUID(),
        chapterPriority: priority,
        isFamilyQuestion: family,
        isFreeTalk: freeTalk,
        answerCount: answers,
        timesShown: shown,
        lastShownAt: lastShown,
        createdAt: created
    )
}

@Suite("Choosing the next question")
struct QuestionPickerTests {
    @Test("Unanswered family questions come before built-in ones")
    func familyQuestionsFirst() {
        let builtIn = (0..<10).map { _ in candidate(priority: 0) }
        let family = candidate(family: true)
        var generator = SeededGenerator(seed: 1)
        for _ in 0..<20 {
            let picked = QuestionPicker().pick(from: builtIn + [family], excluding: [], allowFreeTalk: true, using: &generator)
            #expect(picked?.id == family.id)
        }
    }

    @Test("An answered family question no longer jumps the queue")
    func answeredFamilyQuestionIsNotFirst() {
        let answeredFamily = candidate(family: true, answers: 1)
        let builtIn = candidate(priority: 0)
        var generator = SeededGenerator(seed: 2)
        let picked = QuestionPicker().pick(from: [answeredFamily, builtIn], excluding: [], allowFreeTalk: false, using: &generator)
        #expect(picked?.id == builtIn.id)
    }

    @Test("Recent decades are asked about before childhood")
    func recentDecadesFirst() {
        let parent = (0..<3).map { _ in candidate(priority: 0) }
        let childhood = (0..<3).map { _ in candidate(priority: 70) }
        let parentIDs = Set(parent.map(\.id))
        var generator = SeededGenerator(seed: 3)
        for _ in 0..<20 {
            let picked = QuestionPicker().pick(from: childhood + parent, excluding: [], allowFreeTalk: false, using: &generator)
            #expect(picked.map { parentIDs.contains($0.id) } == true)
        }
    }

    @Test("Skipped questions sink below ones not yet asked")
    func skippedQuestionsSink() {
        let skipped = candidate(priority: 0, shown: 2)
        let fresh = candidate(priority: 70)
        var generator = SeededGenerator(seed: 4)
        let picked = QuestionPicker().pick(from: [skipped, fresh], excluding: [], allowFreeTalk: false, using: &generator)
        #expect(picked?.id == fresh.id)
    }

    @Test("Excluded questions are never picked while others remain")
    func excludedAreSkipped() {
        let first = candidate(priority: 0)
        let second = candidate(priority: 10)
        var generator = SeededGenerator(seed: 5)
        for _ in 0..<20 {
            let picked = QuestionPicker().pick(from: [first, second], excluding: [first.id], allowFreeTalk: false, using: &generator)
            #expect(picked?.id == second.id)
        }
    }

    @Test("Free talk is never offered when not allowed")
    func freeTalkRespectsAllowance() {
        let freeTalk = candidate(freeTalk: true)
        let others = (0..<5).map { _ in candidate(priority: 0) }
        var generator = SeededGenerator(seed: 6)
        for _ in 0..<50 {
            let picked = QuestionPicker().pick(from: [freeTalk] + others, excluding: [], allowFreeTalk: false, using: &generator)
            #expect(picked?.id != freeTalk.id)
        }
    }

    @Test("Free talk comes up now and then when allowed")
    func freeTalkSometimes() {
        let freeTalk = candidate(freeTalk: true)
        let others = (0..<5).map { _ in candidate(priority: 0) }
        var generator = SeededGenerator(seed: 7)
        var count = 0
        for _ in 0..<600 {
            if QuestionPicker().pick(from: [freeTalk] + others, excluding: [], allowFreeTalk: true, using: &generator)?.id == freeTalk.id {
                count += 1
            }
        }
        #expect(count > 40 && count < 200)
    }

    @Test("When everything is answered, the longest-unasked comes back")
    func leastRecentWhenAllAnswered() {
        let recent = candidate(answers: 1, lastShown: Date(timeIntervalSince1970: 2_000_000))
        let old = candidate(answers: 1, lastShown: Date(timeIntervalSince1970: 1_000))
        var generator = SeededGenerator(seed: 8)
        let picker = QuestionPicker(shortlistSize: 1, freeTalkEvery: 6)
        let picked = picker.pick(from: [recent, old], excluding: [], allowFreeTalk: false, using: &generator)
        #expect(picked?.id == old.id)
    }

    @Test("An empty list gives nothing")
    func emptyList() {
        var generator = SeededGenerator(seed: 9)
        #expect(QuestionPicker().pick(from: [], excluding: [], allowFreeTalk: true, using: &generator) == nil)
    }
}

@Suite("Joining transcription pieces")
struct TranscriptJoinerTests {
    @Test func joinsWithSingleSpaces() {
        #expect(TranscriptJoiner.join(["She was maybe five.", "  We were outside. ", ""]) == "She was maybe five. We were outside.")
    }

    @Test func attachesLeadingPunctuation() {
        #expect(TranscriptJoiner.join(["I let go anyway", ", and she rode off."]) == "I let go anyway, and she rode off.")
    }
}
