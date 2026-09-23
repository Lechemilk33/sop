import Foundation
import SwiftData

/// One story, in his own voice. The recording is the story; the transcript is
/// only there to read along and is never used to rewrite what he said.
@Model
final class Story {
    var uuid: UUID = UUID()
    var title: String = ""
    @Attribute(.externalStorage) var audioData: Data?
    /// File extension of `audioData`, e.g. "m4a".
    var audioFileExtension: String = "m4a"
    var duration: Double = 0
    /// His words, written down on the iPhone. The family can correct it.
    var transcript: String = ""
    var transcriptStateRaw: String = TranscriptState.pending.rawValue
    var recordedAt: Date = Date()
    /// The question exactly as it was asked, kept even if the question changes.
    var promptText: String = ""
    /// Roughly when the story happened, if the family adds it.
    var year: Int?
    /// New stories wait for the family to check the title and chapter.
    var needsReview: Bool = true
    var isImported: Bool = false
    var playCount: Int = 0
    var lastPlayedAt: Date?

    var chapter: Chapter?
    var question: Question?
    var photo: Photo?
    var people: [Person]? = []

    init(title: String, promptText: String, recordedAt: Date = Date()) {
        self.title = title
        self.promptText = promptText
        self.recordedAt = recordedAt
    }
}

enum TranscriptState: String, Codable, CaseIterable {
    /// Waiting to be written down.
    case pending
    /// Being written down right now.
    case working
    case done
    case failed
    /// This iPhone can't write stories down.
    case unavailable
}

extension Story {
    var transcriptState: TranscriptState {
        get { TranscriptState(rawValue: transcriptStateRaw) ?? .pending }
        set { transcriptStateRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt.isEmpty ? "A story" : prompt
    }

    var hasTranscript: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var sortedPeople: [Person] {
        (people ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var photoCacheKey: String { "story-photo-\(uuid.uuidString)" }
}
