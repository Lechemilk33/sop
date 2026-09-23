import Foundation
import SwiftData

/// Someone important in his life. Shown in My people with a real photo, their
/// name, and what they are to him ("My daughter").
///
/// Every stored property has a default and every relationship is optional so
/// the model can sync through iCloud (CloudKit) when the family turns it on.
@Model
final class Person {
    /// Stable identity across devices and exports.
    var uuid: UUID = UUID()
    var name: String = ""
    /// Written from his point of view, e.g. "My daughter".
    var relationship: String = ""
    /// Up to three short lines, e.g. "Lives in Chicago with Jake."
    var facts: [String] = []
    @Attribute(.externalStorage) var photoData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    /// A short hello in their own voice ("Hi Dad, it's Emily").
    @Attribute(.externalStorage) var helloAudio: Data?
    var helloDuration: Double = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Story.people)
    var stories: [Story]? = []

    @Relationship(deleteRule: .nullify, inverse: \Photo.people)
    var photos: [Photo]? = []

    @Relationship(deleteRule: .nullify, inverse: \Question.askedBy)
    var questionsAsked: [Question]? = []

    init(name: String, relationship: String, sortOrder: Int) {
        self.name = name
        self.relationship = relationship
        self.sortOrder = sortOrder
    }
}

extension Person {
    var photoCacheKey: String { "person-photo-\(uuid.uuidString)" }
    var thumbnailCacheKey: String { "person-thumb-\(uuid.uuidString)" }

    /// Facts with empty lines removed.
    var visibleFacts: [String] {
        facts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var storyCount: Int { stories?.count ?? 0 }
}
