import Foundation
import SwiftData

/// If the app was closed in the middle of a story (battery, crash, restart),
/// the raw recording is still on disk. On the next launch this turns it into a
/// story and flags it for the family to check.
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

        for file in files where ["caf", "m4a"].contains(file.pathExtension.lowercased()) {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            // A few kilobytes is only a header: nothing was said.
            if (values?.fileSize ?? 0) < 16_000 {
                try? fileManager.removeItem(at: file)
                continue
            }
            let recordedAt = values?.creationDate ?? Date()
            let finished: FinishedRecording
            if file.pathExtension.lowercased() == "caf" {
                finished = await AudioConverter.finalizeRecording(at: file)
            } else {
                finished = FinishedRecording(
                    fileURL: file,
                    fileExtension: "m4a",
                    duration: await AudioConverter.duration(of: file)
                )
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
            story.duration = finished.duration
            story.chapter = Seeder.chapter(forKey: QuestionBank.moreStoriesKey, in: context)
            story.needsReview = true
            do {
                try context.save()
                try? fileManager.removeItem(at: finished.fileURL)
                transcription.enqueue(story)
            } catch {
                // Keep the file; the next launch will try again.
                context.delete(story)
            }
        }
    }
}
