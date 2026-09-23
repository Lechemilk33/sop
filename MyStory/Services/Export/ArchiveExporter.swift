import Foundation
import SwiftData

/// Makes the saved copy: one folder (zipped for sharing) with every original
/// recording, the words in text files, the photos, `stories.json`, and
/// "Open me.html", which plays everything in any web browser.
@MainActor
struct ArchiveExporter {
    struct Output {
        let zipURL: URL
        let storyCount: Int
        let photoCount: Int
    }

    enum ExportError: Error {
        case nothingToSave
    }

    let context: ModelContext
    let ownerName: String

    func makeArchive(progress: @escaping @MainActor (Double) -> Void) async throws -> Output {
        let fileManager = FileManager.default
        let people = try context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.sortOrder)]))
        let chapters = try context.fetch(FetchDescriptor<Chapter>(sortBy: [SortDescriptor(\.sortOrder)]))
        let stories = try context.fetch(FetchDescriptor<Story>(sortBy: [SortDescriptor(\.recordedAt)]))
        let photos = try context.fetch(FetchDescriptor<Photo>(sortBy: [SortDescriptor(\.addedAt)]))
        guard !stories.isEmpty || !people.isEmpty || !photos.isEmpty else { throw ExportError.nothingToSave }

        let folderName = FileNaming.folderName(for: ownerName)
        let workRoot = fileManager.temporaryDirectory.appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
        let root = workRoot.appendingPathComponent(folderName, isDirectory: true)
        defer { try? fileManager.removeItem(at: workRoot) }
        for sub in ["Stories", "People", "Photos"] {
            try fileManager.createDirectory(at: root.appendingPathComponent(sub, isDirectory: true), withIntermediateDirectories: true)
        }

        let totalItems = Double(max(1, people.count + stories.count + photos.count))
        var doneItems = 0.0
        func step() {
            doneItems += 1
            progress(min(0.95, doneItems / totalItems))
        }

        // People
        var takenPeople = Set<String>()
        var personEntries: [ArchiveManifest.PersonEntry] = []
        for person in people {
            let base = FileNaming.sanitized(person.name, fallback: "Someone")
            var photoPath: String?
            if let data = person.photoData {
                let name = FileNaming.unique(base, ext: "jpg", taken: &takenPeople)
                try data.write(to: root.appendingPathComponent("People/\(name)"))
                photoPath = "People/\(name)"
            }
            var helloPath: String?
            if let data = person.helloAudio {
                let name = FileNaming.unique("\(base) - hello", ext: "m4a", taken: &takenPeople)
                try data.write(to: root.appendingPathComponent("People/\(name)"))
                helloPath = "People/\(name)"
            }
            personEntries.append(.init(
                name: person.name,
                relationship: person.relationship,
                facts: person.visibleFacts,
                photoPath: photoPath,
                helloPath: helloPath
            ))
            step()
            await Task.yield()
        }

        // Photos
        var takenPhotos = Set<String>()
        var photoPaths: [PersistentIdentifier: String] = [:]
        var photoEntries: [ArchiveManifest.PhotoEntry] = []
        for (index, photo) in photos.enumerated() {
            guard let data = photo.imageData ?? photo.thumbnailData else { continue }
            let captionPart = photo.caption.isEmpty ? "" : " " + FileNaming.sanitized(photo.caption, fallback: "", maxLength: 50)
            let name = FileNaming.unique(String(format: "Photo %03d", index + 1) + captionPart, ext: "jpg", taken: &takenPhotos)
            try data.write(to: root.appendingPathComponent("Photos/\(name)"))
            let path = "Photos/\(name)"
            photoPaths[photo.persistentModelID] = path
            photoEntries.append(.init(
                path: path,
                caption: photo.caption,
                people: (photo.people ?? []).map(\.name),
                year: photo.year
            ))
            step()
            await Task.yield()
        }

        // Stories, by chapter, oldest first within each chapter.
        var takenStories = Set<String>()
        var chapterEntries: [ArchiveManifest.ChapterEntry] = []
        var groups: [(name: String, stories: [Story])] = chapters.map { chapter -> (name: String, stories: [Story]) in
            let chapterStories = stories.filter { $0.chapter?.persistentModelID == chapter.persistentModelID }
            return (name: chapter.name, stories: chapterStories)
        }
        let unfiled = stories.filter { $0.chapter == nil }
        if !unfiled.isEmpty {
            groups.append((name: "More stories", stories: unfiled))
        }

        for group in groups where !group.stories.isEmpty {
            var entries: [ArchiveManifest.StoryEntry] = []
            for story in group.stories {
                let base = FileNaming.sanitized(
                    "\(DayText.isoDay(story.recordedAt)) \(story.displayTitle)",
                    fallback: DayText.isoDay(story.recordedAt)
                )
                var audioPath: String?
                if let data = story.audioData {
                    audioPath = try await writeAudio(data, fileExtension: story.audioFileExtension, base: base, into: root, taken: &takenStories)
                }
                let transcriptName = FileNaming.unique(base, ext: "txt", taken: &takenStories)
                try transcriptText(for: story, chapterName: group.name)
                    .write(to: root.appendingPathComponent("Stories/\(transcriptName)"), atomically: true, encoding: .utf8)

                entries.append(.init(
                    title: story.displayTitle,
                    prompt: story.promptText,
                    recordedAt: story.recordedAt,
                    durationSeconds: story.duration,
                    audioPath: audioPath,
                    transcriptPath: "Stories/\(transcriptName)",
                    transcript: story.transcript,
                    people: story.sortedPeople.map(\.name),
                    photoPath: story.photo.flatMap { photoPaths[$0.persistentModelID] },
                    year: story.year
                ))
                step()
                await Task.yield()
            }
            chapterEntries.append(.init(name: group.name, stories: entries))
        }

        let manifest = ArchiveManifest(
            ownerName: ownerName,
            createdAt: Date(),
            people: personEntries,
            chapters: chapterEntries,
            photos: photoEntries
        )
        try manifest.jsonData().write(to: root.appendingPathComponent("stories.json"))
        try ArchiveHTML.render(manifest, fontFaces: Self.bundledFontFaces())
            .write(to: root.appendingPathComponent("Open me.html"), atomically: true, encoding: .utf8)

        let exportsDirectory = URL.cachesDirectory.appendingPathComponent("Saved copies", isDirectory: true)
        try fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
        let zipURL = exportsDirectory.appendingPathComponent("\(folderName) \(DayText.isoDay(Date())).zip")
        let sourceFolder = root
        try await Task.detached(priority: .userInitiated) {
            try Self.zip(folder: sourceFolder, to: zipURL)
        }.value
        progress(1)
        return Output(zipURL: zipURL, storyCount: manifest.storyCount, photoCount: photoEntries.count)
    }

    // MARK: - Private

    /// Writes a story's recording. Browsers can't play `.caf`, so those are
    /// converted to `.m4a` first.
    private func writeAudio(
        _ data: Data,
        fileExtension: String,
        base: String,
        into root: URL,
        taken: inout Set<String>
    ) async throws -> String {
        let ext = fileExtension.lowercased()
        if ext == "caf" {
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
            try data.write(to: temporary)
            defer { try? FileManager.default.removeItem(at: temporary) }
            let name = FileNaming.unique(base, ext: "m4a", taken: &taken)
            try await AudioConverter.convertToM4A(from: temporary, to: root.appendingPathComponent("Stories/\(name)"))
            return "Stories/\(name)"
        }
        let name = FileNaming.unique(base, ext: ext.isEmpty ? "m4a" : ext, taken: &taken)
        try data.write(to: root.appendingPathComponent("Stories/\(name)"))
        return "Stories/\(name)"
    }

    private func transcriptText(for story: Story, chapterName: String) -> String {
        var lines = [story.displayTitle, ""]
        lines.append("Told \(DayText.long(story.recordedAt)) (\(DurationText.spoken(story.duration)))")
        lines.append("Chapter: \(chapterName)")
        if !story.promptText.isEmpty { lines.append("Question: \(story.promptText)") }
        let people = story.sortedPeople.map(\.name)
        if !people.isEmpty { lines.append("With: \(people.joined(separator: ", "))") }
        if let year = story.year { lines.append("Around: \(year)") }
        lines.append("")
        lines.append(story.hasTranscript ? story.transcript : "(The words haven't been written down for this one.)")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func bundledFontFaces() -> [ArchiveHTML.FontFace] {
        [("AtkinsonHyperlegibleNext-Regular", 400), ("AtkinsonHyperlegibleNext-Bold", 700)].compactMap { name, weight in
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return ArchiveHTML.FontFace(weight: weight, base64TrueType: data.base64EncodedString())
        }
    }

    /// Zips a folder using the system's built-in archiver.
    nonisolated private static func zip(folder: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading], error: &coordinatorError) { zippedURL in
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: zippedURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
    }
}
