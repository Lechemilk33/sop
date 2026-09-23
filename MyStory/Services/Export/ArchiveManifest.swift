import Foundation

/// Everything in a saved copy, described in plain data. Written next to the
/// files as `stories.json` so the copy can be read by any future program.
struct ArchiveManifest: Codable, Equatable {
    struct PersonEntry: Codable, Equatable {
        var name: String
        var relationship: String
        var facts: [String]
        var photoPath: String?
        var helloPath: String?
    }

    struct StoryEntry: Codable, Equatable {
        var title: String
        var prompt: String
        var recordedAt: Date
        var durationSeconds: Double
        var audioPath: String?
        var transcriptPath: String?
        var transcript: String
        var people: [String]
        var photoPath: String?
        var year: Int?
    }

    struct ChapterEntry: Codable, Equatable {
        var name: String
        var stories: [StoryEntry]
    }

    struct PhotoEntry: Codable, Equatable {
        var path: String
        var caption: String
        var people: [String]
        var year: Int?
    }

    var ownerName: String
    var createdAt: Date
    var people: [PersonEntry]
    var chapters: [ChapterEntry]
    var photos: [PhotoEntry]

    var storyCount: Int {
        chapters.reduce(0) { $0 + $1.stories.count }
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}
