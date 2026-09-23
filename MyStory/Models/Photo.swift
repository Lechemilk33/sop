import Foundation
import SwiftData

/// An old photo the family added. Photos are the best memory prompts, so each
/// one can become a question: "Tell me about this photo."
@Model
final class Photo {
    var uuid: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var caption: String = ""
    /// Roughly when it was taken, if known.
    var year: Int?
    var addedAt: Date = Date()

    var chapter: Chapter?
    var people: [Person]? = []

    @Relationship(deleteRule: .nullify, inverse: \Story.photo)
    var stories: [Story]? = []

    /// Deleting a photo also removes its "Tell me about this photo" question.
    @Relationship(deleteRule: .cascade, inverse: \Question.photo)
    var questions: [Question]? = []

    init(imageData: Data?, thumbnailData: Data?) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
    }
}

extension Photo {
    var imageCacheKey: String { "photo-\(uuid.uuidString)" }
    var thumbnailCacheKey: String { "photo-thumb-\(uuid.uuidString)" }

    /// The question that asks him about this photo, if there is one.
    var promptQuestion: Question? { questions?.first }
}
