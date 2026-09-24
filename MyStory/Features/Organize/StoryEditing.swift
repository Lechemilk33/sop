import Foundation
import SwiftData

/// The small changes he can make to a story, shared by the screens after
/// "Saved" and by "About this story". Each is saved straight away.
@MainActor
enum StoryEditing {
    /// A new name. An empty box keeps the name the story already has.
    static func rename(_ story: Story, to raw: String) {
        let name = StoryTitles.cleaned(raw)
        guard !name.isEmpty, name != story.title else { return }
        story.title = name
        try? story.modelContext?.save()
    }

    /// Adds someone to the story, or takes them off.
    static func togglePerson(_ person: Person, in story: Story) {
        var chosen = story.people ?? []
        if let index = chosen.firstIndex(where: { $0.persistentModelID == person.persistentModelID }) {
            chosen.remove(at: index)
        } else {
            chosen.append(person)
        }
        story.people = chosen
        try? story.modelContext?.save()
    }
}

/// Where chapters sit in My stories.
@MainActor
enum ChapterOrdering {
    /// A new chapter goes just before More stories, which always stays last.
    static func add(_ chapter: Chapter, in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Chapter>())) ?? []
        if let more = existing.first(where: { $0.key == QuestionBank.moreStoriesKey }) {
            let position = more.sortOrder
            for other in existing where other.sortOrder >= position {
                other.sortOrder += 1
            }
            chapter.sortOrder = position
        } else {
            chapter.sortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        }
        context.insert(chapter)
    }

    /// Chapters whose names hold a meaning the app relies on: More stories
    /// catches stories without a place, and My thoughts holds free talk.
    static func isRenamable(_ chapter: Chapter) -> Bool {
        chapter.key != QuestionBank.moreStoriesKey && chapter.key != QuestionBank.thoughtsKey
    }
}
