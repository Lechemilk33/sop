import Foundation
import Testing
@testable import MyStory

@Suite("The note kept beside a recording")
struct RecordingNoteTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("note-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func rawAndCompactRecordingsShareOneNote() {
        let raw = URL(fileURLWithPath: "/tmp/InProgress/ABC.caf")
        let compact = URL(fileURLWithPath: "/tmp/InProgress/ABC.m4a")
        #expect(RecordingNote.url(forRecordingAt: raw) == RecordingNote.url(forRecordingAt: compact))
        #expect(RecordingNote.url(forRecordingAt: raw).lastPathComponent == "ABC.json")
    }

    @Test func keepsEverythingAboutTheStory() throws {
        let directory = try folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recording = directory.appendingPathComponent("story.caf")
        let note = RecordingNote(
            title: "The summer at the lake",
            promptText: "Tell me about a summer you loved.",
            questionID: UUID(),
            chapterID: UUID(),
            photoID: nil,
            peopleIDs: [UUID(), UUID()],
            startedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        note.write(besideRecordingAt: recording)
        #expect(RecordingNote.read(besideRecordingAt: recording) == note)
        // The compact copy made from it finds the same note.
        #expect(RecordingNote.read(besideRecordingAt: directory.appendingPathComponent("story.m4a")) == note)
        RecordingNote.remove(besideRecordingAt: recording)
        #expect(RecordingNote.read(besideRecordingAt: recording) == nil)
    }

    @Test func aMissingOrBrokenNoteIsNil() throws {
        let directory = try folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recording = directory.appendingPathComponent("story.caf")
        #expect(RecordingNote.read(besideRecordingAt: recording) == nil)
        try Data("not json".utf8).write(to: RecordingNote.url(forRecordingAt: recording))
        #expect(RecordingNote.read(besideRecordingAt: recording) == nil)
    }
}

@Suite("Keeping the raw recording until its copy is whole")
struct ConversionCheckTests {
    @Test func aWholeCopyIsAccepted() {
        #expect(ConversionCheck.isComplete(converted: 600, original: 600))
        #expect(ConversionCheck.isComplete(converted: 599, original: 600))
        // Encoding can add a little.
        #expect(ConversionCheck.isComplete(converted: 600.2, original: 600))
    }

    @Test func aShortCopyIsRefused() {
        #expect(!ConversionCheck.isComplete(converted: 300, original: 600))
        #expect(!ConversionCheck.isComplete(converted: 3000, original: 3600))
        #expect(!ConversionCheck.isComplete(converted: 0, original: 600))
        #expect(!ConversionCheck.isComplete(converted: .nan, original: 600))
    }

    @Test func anUnknownOriginalTrustsAnyRealCopy() {
        #expect(ConversionCheck.isComplete(converted: 12, original: 0))
        #expect(!ConversionCheck.isComplete(converted: 0, original: 0))
    }
}
