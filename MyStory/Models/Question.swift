import Foundation
import SwiftData

/// A question that invites a story ("Tell me about…", never "Do you remember…?").
/// Built-in questions come from `QuestionBank`; the family can add their own,
/// optionally recorded in their own voice.
@Model
final class Question {
    var uuid: UUID = UUID()
    /// Stable key for built-in questions; empty for family questions.
    var key: String = ""
    var text: String = ""
    var isBuiltIn: Bool = false
    /// "What's on your mind today?" — stories go to My thoughts.
    var isFreeTalk: Bool = false
    var isHidden: Bool = false
    var timesShown: Int = 0
    var lastShownAt: Date?
    var createdAt: Date = Date()
    /// The question read out in a family member's own voice.
    @Attribute(.externalStorage) var recordedAudio: Data?

    var chapter: Chapter?
    var askedBy: Person?
    var photo: Photo?

    @Relationship(deleteRule: .nullify, inverse: \Story.question)
    var stories: [Story]? = []

    init(text: String, chapter: Chapter?, key: String = "", isBuiltIn: Bool = false, isFreeTalk: Bool = false) {
        self.text = text
        self.chapter = chapter
        self.key = key
        self.isBuiltIn = isBuiltIn
        self.isFreeTalk = isFreeTalk
    }
}

extension Question {
    var answerCount: Int { stories?.count ?? 0 }
}
