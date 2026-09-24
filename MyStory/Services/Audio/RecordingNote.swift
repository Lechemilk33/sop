import Foundation

/// What a story being recorded is about, kept as a small file next to its
/// recording. If the app closes before the story is stored, the rescued
/// story keeps its name, question, chapter, photo and people, instead of
/// becoming "A story you told on …" in More stories.
struct RecordingNote: Codable, Equatable, Sendable {
    var title: String
    var promptText: String
    var questionID: UUID?
    var chapterID: UUID?
    var photoID: UUID?
    var peopleIDs: [UUID]
    var startedAt: Date

    init(
        title: String = "",
        promptText: String = "",
        questionID: UUID? = nil,
        chapterID: UUID? = nil,
        photoID: UUID? = nil,
        peopleIDs: [UUID] = [],
        startedAt: Date = Date()
    ) {
        self.title = title
        self.promptText = promptText
        self.questionID = questionID
        self.chapterID = chapterID
        self.photoID = photoID
        self.peopleIDs = peopleIDs
        self.startedAt = startedAt
    }

    /// The note that goes with a recording: the same name, ending in `.json`.
    /// The raw `.caf` and its `.m4a` share one note.
    static func url(forRecordingAt recording: URL) -> URL {
        recording.deletingPathExtension().appendingPathExtension("json")
    }

    func write(besideRecordingAt recording: URL) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.url(forRecordingAt: recording), options: .atomic)
    }

    static func read(besideRecordingAt recording: URL) -> RecordingNote? {
        guard let data = try? Data(contentsOf: url(forRecordingAt: recording)) else { return nil }
        return try? JSONDecoder().decode(RecordingNote.self, from: data)
    }

    static func remove(besideRecordingAt recording: URL) {
        try? FileManager.default.removeItem(at: url(forRecordingAt: recording))
    }
}
