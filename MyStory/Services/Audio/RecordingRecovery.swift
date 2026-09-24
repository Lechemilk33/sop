import Foundation
import SwiftData

/// If the app was closed in the middle of a story (battery, crash, restart),
/// or a story couldn't be stored (for example, the iPhone was full), the raw
/// recording is still on disk. This turns it into a story and flags it for the
/// family to check. It runs at launch and whenever the app comes back to the
/// foreground while nothing is being recorded.
///
/// The note saved next to each recording (`RecordingNote`) gives the rescued
/// story its name, question, chapter, photo and people. A recording is only
/// ever deleted here if it's certainly shorter than a second and a half.
@MainActor
enum RecordingRecovery {
    /// Room kept free on top of what storing a story needs.
    private static let spareBytes: Int64 = 50_000_000

    static func recoverUnfinishedRecordings(into context: ModelContext, transcription: TranscriptionService) async {
        let directory = StoryRecorder.inProgressDirectory
        let fileManager = FileManager.default
        // Unfinished family clips (a hello, a recorded question) are not stories.
        try? fileManager.removeItem(at: StoryRecorder.clipsDirectory)
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else { return }

        func names(_ ext: String) -> Set<String> {
            Set(files.filter { $0.pathExtension.lowercased() == ext }.map { $0.deletingPathExtension().lastPathComponent })
        }
        let rawNames = names("caf")
        let recordingNames = rawNames.union(names("m4a"))

        for file in files {
            // Out of time in the background: the rest waits for next time.
            if Task.isCancelled { return }
            let ext = file.pathExtension.lowercased()
            let name = file.deletingPathExtension().lastPathComponent
            if ext == "json" {
                // A note whose story was stored, or never recorded.
                if !recordingNames.contains(name) {
                    try? fileManager.removeItem(at: file)
                }
                continue
            }
            guard ext == "caf" || ext == "m4a" else { continue }
            // A half-written .m4a next to its .caf means conversion was cut off;
            // the .caf is the real recording.
            if ext == "m4a", rawNames.contains(name) {
                try? fileManager.removeItem(at: file)
                continue
            }
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            if await isCertainlyTooShort(file, isRaw: ext == "caf", size: size) {
                try? fileManager.removeItem(at: file)
                RecordingNote.remove(besideRecordingAt: file)
                continue
            }
            // Converting and storing need room. Without it, the recording
            // waits safely until the family makes some, rather than being
            // tried again every time the app opens.
            let roomNeeded = (ext == "caf" ? size / 4 : 0) + size + spareBytes
            if let free = await freeSpace(), free < roomNeeded {
                continue
            }

            let finished: FinishedRecording
            if ext == "caf" {
                guard let converted = try? await AudioConverter.finalizeRecording(at: file) else { return }
                finished = converted
            } else {
                let seconds = await AudioConverter.duration(of: file)
                finished = FinishedRecording(fileURL: file, fileExtension: "m4a", duration: seconds, measuredDuration: 0)
            }
            // Mapped, not read into memory, however long the story is.
            guard let data = try? Data(contentsOf: finished.fileURL, options: .alwaysMapped) else { continue }

            let note = RecordingNote.read(besideRecordingAt: file)
            let recordedAt = note?.startedAt ?? values?.creationDate ?? Date()
            let title = note.map { StoryTitles.cleaned($0.title) } ?? ""
            let story = Story(
                title: title.isEmpty ? "A story you told on \(DayText.full(recordedAt))" : title,
                promptText: note?.promptText ?? "",
                recordedAt: recordedAt
            )
            context.insert(story)
            story.audioData = data
            story.audioFileExtension = finished.fileExtension
            story.duration = finished.bestDuration
            story.chapter = chapter(note?.chapterID, in: context)
                ?? Seeder.chapter(forKey: QuestionBank.moreStoriesKey, in: context)
            story.question = question(note?.questionID, in: context)
            story.photo = photo(note?.photoID, in: context)
            story.people = people(note?.peopleIDs ?? [], in: context)
            story.needsReview = true
            do {
                try context.save()
                try? fileManager.removeItem(at: finished.fileURL)
                RecordingNote.remove(besideRecordingAt: file)
                transcription.enqueue(story)
            } catch {
                // Keep the file; the next attempt will try again.
                context.rollback()
            }
        }
    }

    /// Only a recording that certainly holds less than a second and a half
    /// may be deleted. Raw audio under 16 KB is just a header (under a fifth
    /// of a second); a compact one needs its length read to be sure.
    private static func isCertainlyTooShort(_ file: URL, isRaw: Bool, size: Int64) async -> Bool {
        if size == 0 { return true }
        if isRaw { return size < 16_000 }
        let seconds = await AudioConverter.duration(of: file)
        return seconds > 0 && seconds < 1.5
    }

    private static func freeSpace() async -> Int64? {
        await Task.detached(priority: .utility) {
            StoryRecorder.availableCapacity()
        }.value
    }

    // MARK: - What the note points to, if it's still there

    private static func chapter(_ id: UUID?, in context: ModelContext) -> Chapter? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Chapter>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func question(_ id: UUID?, in context: ModelContext) -> Question? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func photo(_ id: UUID?, in context: ModelContext) -> Photo? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Photo>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func people(_ ids: [UUID], in context: ModelContext) -> [Person] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Person>(predicate: #Predicate { ids.contains($0.uuid) })
        return (try? context.fetch(descriptor)) ?? []
    }
}
