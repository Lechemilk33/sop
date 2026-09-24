import Foundation
import SwiftData

/// Adds the built-in chapters and questions, keeps them up to date with
/// `QuestionBank`, and cleans up duplicates that iCloud sync can create when
/// two devices seed at the same time. Safe to run on every launch.
///
/// When there are duplicates, every device keeps the copy with the smallest
/// uuid. Picking the same one everywhere matters: if two devices each kept a
/// different copy, sync would delete both. Whatever the family changed on
/// the copy that goes (a chapter's name, picture or place) is kept.
@MainActor
enum Seeder {
    static func run(in context: ModelContext) throws {
        let chaptersByKey = try ensureChapters(in: context)
        try ensureQuestions(in: context, chaptersByKey: chaptersByKey)
        try fileLooseStories(in: context, chaptersByKey: chaptersByKey)
        if context.hasChanges {
            try context.save()
        }
    }

    private static func ensureChapters(in context: ModelContext) throws -> [String: Chapter] {
        let existing = try context.fetch(FetchDescriptor<Chapter>())
            .sorted { $0.uuid.uuidString < $1.uuid.uuidString }
        var byKey: [String: Chapter] = [:]
        for chapter in existing where !chapter.key.isEmpty {
            if let keeper = byKey[chapter.key] {
                for story in Array(chapter.stories ?? []) { story.chapter = keeper }
                for question in Array(chapter.questions ?? []) { question.chapter = keeper }
                for photo in Array(chapter.photos ?? []) { photo.chapter = keeper }
                keepCustomizations(of: chapter, in: keeper)
                context.delete(chapter)
            } else {
                byKey[chapter.key] = chapter
            }
        }
        for seed in QuestionBank.chapters where byKey[seed.key] == nil {
            let chapter = Chapter(
                key: seed.key,
                name: seed.name,
                symbolName: seed.symbolName,
                sortOrder: seed.sortOrder,
                askPriority: seed.askPriority
            )
            context.insert(chapter)
            byKey[seed.key] = chapter
        }
        return byKey
    }

    /// A duplicate chapter about to go: anything the family changed on it
    /// (and not on the copy that stays) moves across.
    private static func keepCustomizations(of duplicate: Chapter, in keeper: Chapter) {
        guard let seed = QuestionBank.chapterSeed(forKey: keeper.key) else { return }
        if keeper.name == seed.name, duplicate.name != seed.name { keeper.name = duplicate.name }
        if keeper.symbolName == seed.symbolName, duplicate.symbolName != seed.symbolName { keeper.symbolName = duplicate.symbolName }
        if keeper.sortOrder == seed.sortOrder, duplicate.sortOrder != seed.sortOrder { keeper.sortOrder = duplicate.sortOrder }
    }

    private static func ensureQuestions(in context: ModelContext, chaptersByKey: [String: Chapter]) throws {
        let existing = try context.fetch(FetchDescriptor<Question>())
            .sorted { $0.uuid.uuidString < $1.uuid.uuidString }
        let seedsByKey = Dictionary(QuestionBank.questions.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var byKey: [String: Question] = [:]
        var retired: [Question] = []
        for question in existing where question.isBuiltIn && !question.key.isEmpty {
            guard seedsByKey[question.key] != nil else {
                retired.append(question)
                continue
            }
            if let keeper = byKey[question.key] {
                merge(question, into: keeper)
                context.delete(question)
            } else {
                byKey[question.key] = question
            }
        }
        for seed in QuestionBank.questions {
            if let question = byKey[seed.key] {
                // Reworded or moved in the bank: every iPhone gets the new version.
                if question.text != seed.text { question.text = seed.text }
                if question.isFreeTalk != seed.isFreeTalk { question.isFreeTalk = seed.isFreeTalk }
                if let chapter = chaptersByKey[seed.chapterKey], question.chapter?.persistentModelID != chapter.persistentModelID {
                    question.chapter = chapter
                }
            } else {
                let question = Question(text: seed.text, chapter: nil, key: seed.key, isBuiltIn: true, isFreeTalk: seed.isFreeTalk)
                context.insert(question)
                question.chapter = chaptersByKey[seed.chapterKey]
                byKey[seed.key] = question
            }
        }
        retire(retired, currentByText: Dictionary(
            byKey.values.map { (QuestionMatching.normalized($0.text), $0) },
            uniquingKeysWith: { first, _ in first }
        ), in: context)
    }

    /// Built-in questions whose key is no longer in the bank (the first
    /// version numbered them). One with the same words as a current question
    /// hands over its stories and history, so he isn't asked it again. One
    /// he has answered, or the family recorded, stays switched off so his
    /// stories keep their link. The rest are removed.
    private static func retire(_ questions: [Question], currentByText: [String: Question], in context: ModelContext) {
        for question in questions {
            if let current = currentByText[QuestionMatching.normalized(question.text)] {
                merge(question, into: current)
                context.delete(question)
            } else if question.answerCount > 0 || question.recordedAudio != nil {
                question.isHidden = true
            } else {
                context.delete(question)
            }
        }
    }

    /// Everything about `question` that matters moves to `keeper`.
    private static func merge(_ question: Question, into keeper: Question) {
        for story in Array(question.stories ?? []) { story.question = keeper }
        keeper.timesShown = max(keeper.timesShown, question.timesShown)
        keeper.lastShownAt = [keeper.lastShownAt, question.lastShownAt].compactMap { $0 }.max()
        keeper.isHidden = keeper.isHidden || question.isHidden
        if keeper.recordedAudio == nil, let audio = question.recordedAudio {
            keeper.recordedAudio = audio
        }
        if keeper.askedBy == nil { keeper.askedBy = question.askedBy }
    }

    /// Every story belongs in a chapter so it can be found in My life. Any
    /// that lost theirs (say, a chapter removed on another device) go to
    /// More stories.
    private static func fileLooseStories(in context: ModelContext, chaptersByKey: [String: Chapter]) throws {
        guard let moreStories = chaptersByKey[QuestionBank.moreStoriesKey] else { return }
        let loose = try context.fetch(FetchDescriptor<Story>(predicate: #Predicate { $0.chapter == nil }))
        for story in loose {
            story.chapter = moreStories
        }
    }

    /// The chapter a story goes in when nothing else decides it.
    static func chapter(forKey key: String, in context: ModelContext) -> Chapter? {
        let descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.key == key })
        return try? context.fetch(descriptor).first
    }
}
