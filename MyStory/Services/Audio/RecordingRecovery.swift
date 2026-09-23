import Foundation
import SwiftData

/// If the app was closed in the middle of a story (battery, crash, restart),
/// or a story couldn't be stored (for example, the iPhone was full), the raw
/// recording is still on disk. This turns it into a story and flags it for the
/// family to check. It runs at launch and whenever the app comes back to the
/// foreground while nothing is being recorded.
@MainActor
enum RecordingRecovery {
    static func recoverUnfinishedRecordings(into context: ModelContext, transcription: TranscriptionService) async {
        let directory = StoryRecorder.inProgressDirectory
        let fileManager = FileManager.default
        // Unfinished family clips (a hello, a recorded question) are not stories.
        try? fileManager.removeItem(at: StoryRecorder.clipsDirectory)
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else { return }

        let rawNames = Set(files.filter { $0.pathExtension.lowercased() == "caf" }.map { $0.deletingPathExtension().lastPathComponent })

        for file in files {
            let ext = file.pathExtension.lowercased()
            guard ext == "caf" || ext == "m4a" else { continue }
            // A half-written .m4a next to its .caf means conversion was cut off;
            // the .caf is the real recording.
            if ext == "m4a", rawNames.contains(file.deletingPathExtension().lastPathComponent) {
                try? fileManager.removeItem(at: file)
                continue
            }
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            // A few kilobytes is only a header: nothing was said.
            if (values?.fileSize ?? 0) < 16_000 {
                try? fileManager.removeItem(at: file)
                continue
            }
            let recordedAt = values?.creationDate ?? Date()
            let finished: FinishedRecording
            if ext == "caf" {
                finished = await AudioConverter.finalizeRecording(at: file)
            } else {
                let seconds = await AudioConverter.duration(of: file)
                finished = FinishedRecording(fileURL: file, fileExtension: "m4a", duration: seconds, measuredDuration: 0)
            }
            guard let data = try? Data(contentsOf: finished.fileURL) else { continue }

            let story = Story(
                title: "A story you told on \(DayText.full(recordedAt))",
                promptText: "",
                recordedAt: recordedAt
            )
            context.insert(story)
            story.audioData = data
            story.audioFileExtension = finished.fileExtension
            story.duration = finished.bestDuration
            story.chapter = Seeder.chapter(forKey: QuestionBank.moreStoriesKey, in: context)
            story.needsReview = true
            do {
                try context.save()
                try? fileManager.removeItem(at: finished.fileURL)
                transcription.enqueue(story)
            } catch {
                // Keep the file; the next attempt will try again.
                context.rollback()
            }
        }
    }
}
