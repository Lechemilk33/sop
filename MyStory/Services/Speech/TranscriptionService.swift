import AVFoundation
import Foundation
import Observation
import Speech
import SwiftData
import UIKit

/// Writes his stories down, entirely on the iPhone, using Apple's
/// SpeechAnalyzer. Nothing is sent anywhere. The words are only for reading
/// along; the recording is always the story.
@MainActor
@Observable
final class TranscriptionService {
    enum Readiness: Equatable {
        case unknown
        /// This iPhone can't write stories down.
        case unavailable
        /// The language files need to be downloaded once.
        case needsDownload
        case downloading
        case ready
        case failed
    }

    private(set) var readiness: Readiness = .unknown
    private(set) var isWorking = false

    private let container: ModelContainer
    @ObservationIgnored private var queue: [PersistentIdentifier] = []
    /// The story being written down right now.
    @ObservationIgnored private var inFlight: PersistentIdentifier?
    /// Counts trips to the background, so a story whose writing-down was cut
    /// short by the phone locking is tried again rather than marked failed.
    @ObservationIgnored private var backgroundTrips = 0
    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?

    init(container: ModelContainer) {
        self.container = container
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.backgroundTrips += 1
            }
        }
    }

    /// Checks whether transcription is ready without downloading anything.
    func refreshReadiness() async {
        guard SpeechTranscriber.isAvailable else {
            readiness = .unavailable
            return
        }
        let transcriber = SpeechTranscriber(locale: await Self.transcriptionLocale(), preset: .transcription)
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed: readiness = .ready
        case .downloading: readiness = .downloading
        case .supported: readiness = .needsDownload
        case .unsupported: readiness = .unavailable
        @unknown default: readiness = .unknown
        }
    }

    /// Downloads the language files if needed (done once, during setup).
    func prepare() async {
        guard SpeechTranscriber.isAvailable else {
            readiness = .unavailable
            return
        }
        readiness = .downloading
        do {
            let transcriber = SpeechTranscriber(locale: await Self.transcriptionLocale(), preset: .transcription)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            readiness = .ready
        } catch {
            readiness = .failed
        }
    }

    /// Queues a story to be written down.
    func enqueue(_ story: Story) {
        story.transcriptState = .pending
        let id = story.persistentModelID
        if !queue.contains(id), id != inFlight {
            queue.append(id)
        }
        startIfNeeded()
    }

    /// Writes a story down again from scratch (family area, "Try again").
    func retranscribe(_ story: Story) {
        story.transcript = ""
        enqueue(story)
    }

    /// Picks up anything left unfinished: at launch, and each time the app
    /// comes back to the front.
    func enqueueUnfinished() {
        let context = container.mainContext
        guard let stories = try? context.fetch(FetchDescriptor<Story>()) else { return }
        for story in stories where story.transcriptState == .pending || story.transcriptState == .working {
            let id = story.persistentModelID
            if !queue.contains(id), id != inFlight {
                queue.append(id)
            }
        }
        startIfNeeded()
    }

    // MARK: - Private

    private func startIfNeeded() {
        guard !isWorking, !queue.isEmpty else { return }
        isWorking = true
        Task { await drainQueue() }
    }

    private func drainQueue() async {
        while !queue.isEmpty {
            let id = queue.removeFirst()
            inFlight = id
            await transcribeStory(id)
            inFlight = nil
        }
        isWorking = false
    }

    private func transcribeStory(_ id: PersistentIdentifier) async {
        let context = container.mainContext
        guard let story = Self.story(id, in: context) else { return }

        guard SpeechTranscriber.isAvailable else {
            story.transcriptState = .unavailable
            try? context.save()
            return
        }
        // Read through a short-lived context, so the recording isn't kept in
        // memory once it's written down.
        guard let audio = Self.story(id, in: ModelContext(container))?.audioData else { return }

        story.transcriptState = .working
        try? context.save()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcribe-\(UUID().uuidString)")
            .appendingPathExtension(story.audioFileExtension)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        // A little time to finish if the phone is locked meanwhile.
        let activity = BackgroundActivity("Write down a story")
        defer { activity.end() }
        let tripsAtStart = backgroundTrips

        let result: Result<String, Error>
        do {
            try await Task.detached(priority: .utility) {
                try audio.write(to: fileURL)
            }.value
            if readiness != .ready {
                await prepare()
            }
            result = .success(try await Self.transcribeFile(at: fileURL, locale: await Self.transcriptionLocale()))
        } catch {
            result = .failure(error)
        }

        // The family may have deleted the story while it was being written
        // down, so look it up again rather than touching the old copy.
        guard let current = Self.story(id, in: context) else { return }
        switch result {
        case .success(let text):
            // Never overwrite words the family has already corrected.
            if !current.hasTranscript {
                current.transcript = text
            }
            current.transcriptState = .done
        case .failure:
            // Cut short by the phone locking: it waits and is tried again
            // when the app is next in front. Otherwise the family can try
            // again from the story.
            current.transcriptState = backgroundTrips == tripsAtStart ? .failed : .pending
        }
        try? context.save()
    }

    /// The story with this ID, or nil if it has been deleted.
    private static func story(_ id: PersistentIdentifier, in context: ModelContext) -> Story? {
        var descriptor = FetchDescriptor<Story>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func transcriptionLocale() async -> Locale {
        await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) ?? Locale(identifier: "en-US")
    }

    private static func transcribeFile(at url: URL, locale: Locale) async throws -> String {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: nil)
        let collector = Task { () throws -> [String] in
            var pieces: [String] = []
            for try await result in transcriber.results where result.isFinal {
                pieces.append(String(result.text.characters))
            }
            return pieces
        }
        let audioFile = try AVAudioFile(forReading: url)
        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return TranscriptJoiner.join(try await collector.value)
    }
}
