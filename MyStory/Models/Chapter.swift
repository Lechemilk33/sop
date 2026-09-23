import Foundation
import SwiftData

/// A chapter of his life, like "Being a dad" or "Work".
@Model
final class Chapter {
    var uuid: UUID = UUID()
    /// Stable key for built-in chapters, e.g. "parent".
    var key: String = ""
    var name: String = ""
    var symbolName: String = "book.fill"
    /// Order in My life (roughly the order of a life).
    var sortOrder: Int = 0
    /// Lower numbers are asked about first. Recent decades come first, because
    /// with Alzheimer's they usually fade before childhood does.
    var askPriority: Int = 50

    @Relationship(deleteRule: .nullify, inverse: \Story.chapter)
    var stories: [Story]? = []

    @Relationship(deleteRule: .nullify, inverse: \Question.chapter)
    var questions: [Question]? = []

    @Relationship(deleteRule: .nullify, inverse: \Photo.chapter)
    var photos: [Photo]? = []

    init(key: String, name: String, symbolName: String, sortOrder: Int, askPriority: Int) {
        self.key = key
        self.name = name
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.askPriority = askPriority
    }
}

extension Chapter {
    var storyCount: Int { stories?.count ?? 0 }

    /// Newest first.
    var sortedStories: [Story] {
        (stories ?? []).sorted { $0.recordedAt > $1.recordedAt }
    }
}
