import Foundation
import SwiftData

/// Makes the saved copy: one folder (zipped for sharing) with every original
/// recording, the words in text files, the photos, the family's recorded
/// questions, `stories.json`, and "Open me.html", which plays everything in
/// any web browser.
///
/// Records are read a few at a time, each batch in its own short-lived
/// context, so even hundreds of hours of recordings never have to fit in
/// memory at once.
@MainActor
struct ArchiveExporter {
    struct Output {
        let zipURL: URL
        let storyCount: Int
        let photoCount: Int
    }

    enum ExportError: Error {
        case nothingToSave
        /// The copy needs about `needed` bytes of free space.
        case notEnoughSpace(needed: Int64)
    }

    let container: ModelContainer
    let ownerName: String

    /// How many records are held in memory at once.
    private static let batchSize = 10
    /// Room left on the iPhone beyond what the copy needs.
    private static let spareBytes: Int64 = 300_000_000
    private static let workFolderPrefix = "Export-"

    private static var copiesDirectory: URL {
        URL.cachesDirectory.appendingPathComponent("Saved copies", isDirectory: true)
    }

    func makeArchive(progress: @escaping @MainActor (Double) -> Void) async throws -> Output {
        // Anything the family just typed is saved first, so it's in the copy.
        try? container.mainContext.save()

        let size = try measure()
        guard size.itemCount > 0 else { throw ExportError.nothingToSave }
        Self.removeOldCopies()
        // The folder and the zip made from it both need room for a moment.
        let needed = size.estimatedBytes * 2 + Self.spareBytes
        if let free = StoryRecorder.availableCapacity(), free < needed {
            throw ExportError.notEnoughSpace(needed: needed)
        }

        do {
            return try await build(itemCount: size.itemCount, progress: progress)
        } catch let error as CocoaError where error.code == .fileWriteOutOfSpace {
            throw ExportError.notEnoughSpace(needed: needed)
        }
    }

    // MARK: - Building the copy

    private func build(itemCount: Int, progress: @escaping @MainActor (Double) -> Void) async throws -> Output {
        let fileManager = FileManager.default
        let folderName = FileNaming.folderName(for: ownerName)
        let workRoot = fileManager.temporaryDirectory
            .appendingPathComponent(Self.workFolderPrefix + UUID().uuidString, isDirectory: true)
        let root = workRoot.appendingPathComponent(folderName, isDirectory: true)
        defer { try? fileManager.removeItem(at: workRoot) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let total = Double(max(1, itemCount))
        var done = 0.0
        func step() {
            done += 1
            progress(min(0.95, done / total))
        }

        // People
        var takenPeople = Set<String>()
        var personEntries: [ArchiveManifest.PersonEntry] = []
        try await forEachInBatches(of: Person.self, sortBy: [SortDescriptor(\.sortOrder)]) { person in
            let base = FileNaming.sanitized(person.name, fallback: "Someone")
            var photoPath: String?
            if let data = person.photoData {
                let name = FileNaming.unique(base, ext: "jpg", taken: &takenPeople)
                try data.write(to: fileURL("People", name, in: root))
                photoPath = "People/\(name)"
            }
            var helloPath: String?
            if let data = person.helloAudio {
                helloPath = try await writeAudio(
                    data,
                    fileExtension: AudioFileType.fileExtension(of: data),
                    base: "\(base) - hello",
                    folder: "People",
                    in: root,
                    taken: &takenPeople
                )
            }
            personEntries.append(.init(
                name: person.name,
                relationship: person.relationship,
                facts: person.visibleFacts,
                photoPath: photoPath,
                helloPath: helloPath
            ))
            step()
        }

        // Photos
        var takenPhotos = Set<String>()
        var photoPaths: [PersistentIdentifier: String] = [:]
        var photoEntries: [ArchiveManifest.PhotoEntry] = []
        try await forEachInBatches(of: Photo.self, sortBy: [SortDescriptor(\.addedAt)]) { photo in
            defer { step() }
            guard let data = photo.imageData ?? photo.thumbnailData else { return }
            let captionPart = photo.caption.isEmpty ? "" : " " + FileNaming.sanitized(photo.caption, fallback: "", maxLength: 50)
            let number = String(format: "Photo %03d", photoEntries.count + 1)
            let name = FileNaming.unique(number + captionPart, ext: "jpg", taken: &takenPhotos)
            try data.write(to: fileURL("Photos", name, in: root))
            let path = "Photos/\(name)"
            photoPaths[photo.persistentModelID] = path
            photoEntries.append(.init(
                path: path,
                caption: photo.caption,
                people: (photo.people ?? []).map(\.name),
                year: photo.year
            ))
        }

        // Stories, oldest first, gathered by chapter.
        let chapters = try chapterList()
        let chapterNames = Dictionary(uniqueKeysWithValues: chapters.map { ($0.id, $0.name) })
        var takenStories = Set<String>()
        var storiesByChapter: [PersistentIdentifier: [ArchiveManifest.StoryEntry]] = [:]
        var unfiled: [ArchiveManifest.StoryEntry] = []
        try await forEachInBatches(of: Story.self, sortBy: [SortDescriptor(\.recordedAt)]) { story in
            let chapterID = story.chapter?.persistentModelID
            let chapterName = chapterID.flatMap { chapterNames[$0] } ?? Self.unfiledChapterName
            let base = FileNaming.sanitized(
                "\(DayText.isoDay(story.recordedAt)) \(story.displayTitle)",
                fallback: DayText.isoDay(story.recordedAt)
            )
            var audioPath: String?
            if let data = story.audioData {
                audioPath = try await writeAudio(
                    data,
                    fileExtension: story.audioFileExtension,
                    base: base,
                    folder: "Stories",
                    in: root,
                    taken: &takenStories
                )
            }
            let transcriptName = FileNaming.unique(base, ext: "txt", taken: &takenStories)
            try transcriptText(for: story, chapterName: chapterName)
                .write(to: fileURL("Stories", transcriptName, in: root), atomically: true, encoding: .utf8)

            let entry = ArchiveManifest.StoryEntry(
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
            )
            if let chapterID, chapterNames[chapterID] != nil {
                storiesByChapter[chapterID, default: []].append(entry)
            } else {
                unfiled.append(entry)
            }
            step()
        }

        var chapterEntries: [ArchiveManifest.ChapterEntry] = []
        for chapter in chapters {
            var stories = storiesByChapter[chapter.id] ?? []
            if chapter.key == QuestionBank.moreStoriesKey, !unfiled.isEmpty {
                stories = (stories + unfiled).sorted { $0.recordedAt < $1.recordedAt }
                unfiled = []
            }
            if !stories.isEmpty {
                chapterEntries.append(.init(name: chapter.name, stories: stories))
            }
        }
        if !unfiled.isEmpty {
            chapterEntries.append(.init(name: Self.unfiledChapterName, stories: unfiled))
        }

        // Questions the family wrote or recorded in their own voice.
        var takenQuestions = Set<String>()
        var questionEntries: [ArchiveManifest.QuestionEntry] = []
        try await forEachInBatches(of: Question.self, sortBy: [SortDescriptor(\.createdAt)]) { question in
            let audio = question.recordedAudio
            let isFamilyQuestion = !question.isBuiltIn && question.photo == nil
            guard isFamilyQuestion || audio != nil else { return }
            let asker = question.askedBy?.name
            var audioPath: String?
            if let audio {
                let label = asker.map { "\($0) asks - \(question.text)" } ?? question.text
                audioPath = try await writeAudio(
                    audio,
                    fileExtension: AudioFileType.fileExtension(of: audio),
                    base: FileNaming.sanitized(label, fallback: "A question"),
                    folder: "Questions",
                    in: root,
                    taken: &takenQuestions
                )
            }
            questionEntries.append(.init(
                text: question.text,
                askedBy: asker,
                audioPath: audioPath,
                photoPath: question.photo.flatMap { photoPaths[$0.persistentModelID] }
            ))
        }

        let manifest = ArchiveManifest(
            ownerName: ownerName,
            createdAt: Date(),
            people: personEntries,
            chapters: chapterEntries,
            photos: photoEntries,
            questions: questionEntries
        )
        try manifest.jsonData().write(to: root.appendingPathComponent("stories.json"))
        try ArchiveHTML.render(manifest, fontFaces: Self.bundledFontFaces())
            .write(to: root.appendingPathComponent("Open me.html"), atomically: true, encoding: .utf8)

        try fileManager.createDirectory(at: Self.copiesDirectory, withIntermediateDirectories: true)
        let zipURL = Self.copiesDirectory.appendingPathComponent("\(folderName) \(DayText.isoDay(Date())).zip")
        let sourceFolder = root
        try await Task.detached(priority: .userInitiated) {
            try Self.zip(folder: sourceFolder, to: zipURL)
        }.value
        progress(1)
        return Output(zipURL: zipURL, storyCount: manifest.storyCount, photoCount: photoEntries.count)
    }

    // MARK: - Reading the stored records

    private static let unfiledChapterName = "More stories"

    private struct Size {
        var itemCount: Int
        var estimatedBytes: Int64
    }

    /// Roughly how big the copy will be, without loading any recordings.
    private func measure() throws -> Size {
        let context = ModelContext(container)
        var storyDescriptor = FetchDescriptor<Story>()
        storyDescriptor.propertiesToFetch = [\.duration, \.audioFileExtension]
        let stories = try context.fetch(storyDescriptor)
        var bytes: Int64 = 0
        for story in stories {
            // Uncompressed .caf is about 88 KB a second; .m4a well under 16 KB.
            let perSecond: Double = story.audioFileExtension.lowercased() == "caf" ? 88_200 : 16_000
            let seconds = story.duration.isFinite ? max(0, story.duration) : 0
            bytes += Int64(seconds * perSecond) + 50_000
        }
        let people = try context.fetchCount(FetchDescriptor<Person>())
        let photos = try context.fetchCount(FetchDescriptor<Photo>())
        let questions = try context.fetchCount(FetchDescriptor<Question>())
        bytes += Int64(people + photos) * 5_000_000 + Int64(questions) * 200_000
        return Size(itemCount: stories.count + people + photos, estimatedBytes: bytes)
    }

    private struct ChapterInfo {
        let id: PersistentIdentifier
        let key: String
        let name: String
    }

    private func chapterList() throws -> [ChapterInfo] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Chapter>(sortBy: [SortDescriptor(\.sortOrder)]))
            .map { ChapterInfo(id: $0.persistentModelID, key: $0.key, name: $0.name) }
    }

    /// Visits every record of one kind, a batch at a time. Each batch gets its
    /// own context, so its recordings and photos are let go once written.
    private func forEachInBatches<T: PersistentModel>(
        of type: T.Type,
        sortBy: [SortDescriptor<T>],
        _ body: (T) async throws -> Void
    ) async throws {
        var offset = 0
        while true {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<T>(sortBy: sortBy)
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = Self.batchSize
            let batch = try context.fetch(descriptor)
            for item in batch {
                try await body(item)
                await Task.yield()
            }
            guard batch.count == Self.batchSize else { return }
            offset += batch.count
        }
    }

    // MARK: - Writing files

    private func fileURL(_ folder: String, _ name: String, in root: URL) throws -> URL {
        let directory = root.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    /// Writes a recording and returns its path in the copy. Browsers can't
    /// play `.caf`, so those are converted to `.m4a` first; if that fails,
    /// the original `.caf` goes in instead, so nothing is left out.
    private func writeAudio(
        _ data: Data,
        fileExtension: String,
        base: String,
        folder: String,
        in root: URL,
        taken: inout Set<String>
    ) async throws -> String {
        let ext = fileExtension.lowercased()
        if ext == "caf" {
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
            try data.write(to: temporary)
            defer { try? FileManager.default.removeItem(at: temporary) }
            var converted = Set(taken)
            let name = FileNaming.unique(base, ext: "m4a", taken: &converted)
            let destination = try fileURL(folder, name, in: root)
            do {
                try await AudioConverter.convertToM4A(from: temporary, to: destination)
                taken = converted
                return "\(folder)/\(name)"
            } catch {
                try? FileManager.default.removeItem(at: destination)
            }
        }
        let name = FileNaming.unique(base, ext: ext.isEmpty ? "m4a" : ext, taken: &taken)
        try data.write(to: fileURL(folder, name, in: root))
        return "\(folder)/\(name)"
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

    /// Only the newest copy is kept on the iPhone. Older ones, and anything
    /// left behind by a copy that was interrupted, are removed so they can't
    /// slowly fill it up.
    private static func removeOldCopies() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: copiesDirectory)
        let temporary = fileManager.temporaryDirectory
        let leftovers = (try? fileManager.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)) ?? []
        for url in leftovers where url.lastPathComponent.hasPrefix(workFolderPrefix) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Zips a folder using the system's built-in archiver. The zip is moved,
    /// not copied, so the iPhone never holds two of it.
    nonisolated private static func zip(folder: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var moveError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading], error: &coordinatorError) { zippedURL in
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: zippedURL, to: destination)
            } catch {
                moveError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let moveError { throw moveError }
    }
}
