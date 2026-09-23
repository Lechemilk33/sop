import Foundation
import SwiftData

/// Adds the built-in chapters and questions, and cleans up duplicates that
/// iCloud sync can create when two devices seed at the same time. Safe to run
/// on every launch.
@MainActor
enum Seeder {
    static func run(in context: ModelContext) throws {
        let chaptersByKey = try ensureChapters(in: context)
        try ensureQuestions(in: context, chaptersByKey: chaptersByKey)
        if context.hasChanges {
            try context.save()
        }
    }

    private static func ensureChapters(in context: ModelContext) throws -> [String: Chapter] {
        let existing = try context.fetch(FetchDescriptor<Chapter>(sortBy: [SortDescriptor(\.sortOrder)]))
        var byKey: [String: Chapter] = [:]
        for chapter in existing where !chapter.key.isEmpty {
            if let keeper = byKey[chapter.key] {
                for story in Array(chapter.stories ?? []) { story.chapter = keeper }
                for question in Array(chapter.questions ?? []) { question.chapter = keeper }
                for photo in Array(chapter.photos ?? []) { photo.chapter = keeper }
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

    private static func ensureQuestions(in context: ModelContext, chaptersByKey: [String: Chapter]) throws {
        let existing = try context.fetch(FetchDescriptor<Question>(sortBy: [SortDescriptor(\.createdAt)]))
        var byKey: [String: Question] = [:]
        for question in existing where question.isBuiltIn && !question.key.isEmpty {
            if let keeper = byKey[question.key] {
                for story in Array(question.stories ?? []) { story.question = keeper }
                keeper.timesShown = max(keeper.timesShown, question.timesShown)
                keeper.isHidden = keeper.isHidden || question.isHidden
                context.delete(question)
            } else {
                byKey[question.key] = question
            }
        }
        for seed in QuestionBank.questions where byKey[seed.key] == nil {
            let question = Question(text: seed.text, chapter: nil, key: seed.key, isBuiltIn: true, isFreeTalk: seed.isFreeTalk)
            context.insert(question)
            question.chapter = chaptersByKey[seed.chapterKey]
        }
    }

    /// The chapter a story goes in when nothing else decides it.
    static func chapter(forKey key: String, in context: ModelContext) -> Chapter? {
        let descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.key == key })
        return try? context.fetch(descriptor).first
    }
}
