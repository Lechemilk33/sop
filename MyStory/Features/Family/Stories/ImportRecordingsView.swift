import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Brings in recordings made before the app, for example with Voice Memos.
struct ImportRecordingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(TranscriptionService.self) private var transcription

    @State private var isChoosing = false
    @State private var isImporting = false
    @State private var resultMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    isChoosing = true
                } label: {
                    FamilyMenuRow(title: "Choose recordings", systemImage: "waveform.badge.plus")
                }
                .disabled(isImporting)
                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Bringing them in…")
                    }
                }
                if let resultMessage {
                    Text(resultMessage)
                        .foregroundStyle(Palette.ink)
                }
            } footer: {
                Text("They're added to More stories and to Check new stories, where you can give each one a title and a chapter. The words are written down on this iPhone.")
            }

            Section("From Voice Memos") {
                Text("1. Open Voice Memos and tap a recording.")
                Text("2. Tap the three dots, then Save to Files.")
                Text("3. Come back here, tap Choose recordings and pick it.")
            }
        }
        .familyBackground()
        .navigationTitle("Old recordings")
        .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                Task { await importFiles(urls) }
            case .failure:
                resultMessage = "Those files couldn't be opened."
            }
        }
    }

    private func importFiles(_ urls: [URL]) async {
        isImporting = true
        resultMessage = nil
        var imported = 0
        for url in urls {
            if await importFile(url) {
                imported += 1
            }
        }
        isImporting = false
        let failed = urls.count - imported
        resultMessage = failed == 0
            ? "Brought in \(imported == 1 ? "1 recording" : "\(imported) recordings")."
            : "Brought in \(imported). \(failed) couldn't be read. The originals are untouched."
    }

    /// Brings in one recording. The original file is never changed.
    private func importFile(_ url: URL) async -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let ext = url.pathExtension.lowercased()
        let workFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext.isEmpty ? "audio" : ext)
        let converted = workFile.deletingPathExtension().appendingPathExtension("m4a")
        defer {
            try? FileManager.default.removeItem(at: workFile)
            try? FileManager.default.removeItem(at: converted)
        }

        do {
            try FileManager.default.copyItem(at: url, to: workFile)
        } catch {
            return false
        }

        // Compressed formats are kept as they are. Everything else, including
        // large .wav files, becomes .m4a; a .wav that won't convert is kept.
        var finalFile = workFile
        var finalExtension = ext
        if !["m4a", "mp3", "aac"].contains(ext) {
            do {
                try await AudioConverter.convertToM4A(from: workFile, to: converted)
                finalFile = converted
                finalExtension = "m4a"
            } catch {
                guard ext == "wav" else { return false }
            }
        }

        let duration = await AudioConverter.duration(of: finalFile)
        guard duration > 0, let data = try? Data(contentsOf: finalFile) else { return false }
        let fileDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
        let recordedAt = await AudioConverter.recordingDate(of: workFile) ?? fileDate ?? Date()
        let title = FileNaming.sanitized(url.deletingPathExtension().lastPathComponent, fallback: "A recording")

        let story = Story(title: title, promptText: "", recordedAt: recordedAt)
        context.insert(story)
        story.audioData = data
        story.audioFileExtension = finalExtension
        story.duration = duration
        story.isImported = true
        story.needsReview = true
        story.chapter = Seeder.chapter(forKey: QuestionBank.moreStoriesKey, in: context)
        do {
            try context.save()
        } catch {
            context.rollback()
            return false
        }
        transcription.enqueue(story)
        return true
    }
}
