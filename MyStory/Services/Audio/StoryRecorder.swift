import AVFoundation
import Observation
import UIKit

/// Records his voice.
///
/// Built so a story is never lost:
/// - It records uncompressed audio into a `.caf` file, which stays readable
///   even if the app is closed mid-story. `RecordingRecovery` turns any
///   leftover file into a story.
/// - It never stops on silence and has no time limit he'd notice. It stops by
///   itself only to protect the story: when the iPhone is nearly full, if the
///   system stops the microphone, or after a two-hour safety limit.
/// - A phone call pauses it; it picks up again by itself when the call ends.
/// - The screen stays awake while it listens, and finishing keeps running
///   briefly in the background if the phone is locked at that moment.
@MainActor
@Observable
final class StoryRecorder {
    enum State: Equatable {
        case idle
        case recording
        /// Paused by a phone call or another app.
        case interrupted
        case finishing
    }

    /// A story he tells, or a short clip a family member records (a hello, or
    /// a question in their own voice). Clips never become stories on recovery.
    enum Kind {
        case story
        case clip
    }

    /// Why a recording stopped without "I'm finished".
    enum StopReason: Equatable {
        case storageAlmostFull
        case systemStopped
        case safetyLimit
    }

    enum RecorderError: Error, Equatable {
        case microphoneNotAllowed
        case notEnoughSpace
        case busy
        case couldNotStart
        case nothingRecorded
    }

    private(set) var state: State = .idle
    /// Seconds recorded so far.
    private(set) var elapsed: TimeInterval = 0
    /// His voice level from 0 to 1, for the listening indicator.
    private(set) var level: Double = 0

    /// Called once if the recording has to stop to protect the story.
    var onMustStop: (@MainActor (StopReason) -> Void)?

    let safetyLimit: TimeInterval = 2 * 60 * 60
    /// Needed to start: about 30 minutes of raw audio plus room to convert it.
    let bytesNeededToStart: Int64 = 250_000_000
    /// Below this while recording, stop and save what there is.
    let bytesNeededToContinue: Int64 = 60_000_000

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var fileURL: URL?
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var ticks = 0
    @ObservationIgnored private var hasAskedToStop = false
    private let events = RecorderEventRelay()

    init() {
        events.onProblem = { [weak self] in
            self?.askToStop(.systemStopped)
        }
    }

    /// Where raw story recordings live until they are safely stored in a story.
    static var inProgressDirectory: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Recordings", isDirectory: true)
            .appendingPathComponent("InProgress", isDirectory: true)
    }

    /// Where family clips are recorded. Leftovers are simply deleted.
    static var clipsDirectory: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Recordings", isDirectory: true)
            .appendingPathComponent("Clips", isDirectory: true)
    }

    /// Free space for important data, in bytes.
    static func availableCapacity() -> Int64? {
        let values = try? URL.applicationSupportDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    var isMicrophoneAllowed: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    var hasAskedForMicrophone: Bool {
        AVAudioApplication.shared.recordPermission != .undetermined
    }

    /// Asks for the microphone. The family does this during setup so he never
    /// sees the system prompt.
    func requestMicrophone() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start(kind: Kind = .story) async throws {
        guard state == .idle else { throw RecorderError.busy }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .undetermined:
            guard await AVAudioApplication.requestRecordPermission() else {
                throw RecorderError.microphoneNotAllowed
            }
        default:
            throw RecorderError.microphoneNotAllowed
        }
        if let free = Self.availableCapacity(), free < bytesNeededToStart {
            throw RecorderError.notEnoughSpace
        }

        try AudioSessionController.activateForRecording()
        let directory = kind == .story ? Self.inProgressDirectory : Self.clipsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(UUID().uuidString).caf")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = events
        guard recorder.prepareToRecord(), recorder.record() else {
            AudioSessionController.finishRecording()
            throw RecorderError.couldNotStart
        }

        self.recorder = recorder
        fileURL = url
        elapsed = 0
        level = 0
        ticks = 0
        hasAskedToStop = false
        state = .recording
        UIApplication.shared.isIdleTimerDisabled = true
        observeInterruptions()
        startMetering()
    }

    /// Picks up again after an interruption.
    func resume() {
        guard state == .interrupted, let recorder else { return }
        do {
            try AudioSessionController.activateForRecording()
            if recorder.record() {
                state = .recording
            }
        } catch {
            state = .interrupted
        }
    }

    /// Stops and returns the finished recording (converted to `.m4a`).
    func finish() async throws -> FinishedRecording {
        guard let recorder, let url = fileURL, state != .finishing else {
            throw RecorderError.nothingRecorded
        }
        state = .finishing
        let measured = recorder.currentTime > 0 ? recorder.currentTime : elapsed
        recorder.stop()
        tearDown()

        // Keep converting for a moment even if the phone is locked right now.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish recording")
        let finished = await AudioConverter.finalizeRecording(at: url, measuredDuration: measured)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }

        state = .idle
        elapsed = 0
        level = 0
        return finished
    }

    // MARK: - Private

    private func askToStop(_ reason: StopReason) {
        guard state == .recording || state == .interrupted, !hasAskedToStop else { return }
        hasAskedToStop = true
        onMustStop?(reason)
    }

    private func tearDown() {
        meterTask?.cancel()
        meterTask = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        recorder?.delegate = nil
        recorder = nil
        fileURL = nil
        UIApplication.shared.isIdleTimerDisabled = false
        AudioSessionController.finishRecording()
    }

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard let recorder else { return }
        guard state == .recording else {
            level = 0
            return
        }
        if !recorder.isRecording {
            // The system stopped the microphone (for example, the disk filled).
            askToStop(.systemStopped)
            return
        }
        recorder.updateMeters()
        let power = Double(recorder.averagePower(forChannel: 0))
        level = max(0, min(1, (power + 50) / 50))
        elapsed = recorder.currentTime

        ticks += 1
        if ticks % 50 == 0, let free = Self.availableCapacity(), free < bytesNeededToContinue {
            askToStop(.storageAlmostFull)
        }
        if elapsed >= safetyLimit {
            askToStop(.safetyLimit)
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            if state == .recording { state = .interrupted }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) { resume() }
        @unknown default:
            break
        }
    }
}

/// Forwards recorder problems (encoding errors, an unexpected stop) to the
/// main actor.
final class RecorderEventRelay: NSObject, AVAudioRecorderDelegate {
    /// Set once on the main actor before recording starts, then only read.
    nonisolated(unsafe) var onProblem: (@MainActor () -> Void)?

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        let handler = onProblem
        Task { @MainActor in handler?() }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let handler = onProblem
        Task { @MainActor in handler?() }
    }
}
