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
/// - A phone call pauses it. It picks up again by itself when the call ends
///   if he's looking at the app; otherwise he sees "Keep going".
/// - The screen stays awake while it listens. Finishing asks for time to
///   run in the background first, and if that time runs out, the recording
///   is left safely on disk for `RecordingRecovery` instead.
/// - A note next to each story's recording (`RecordingNote`) says what it's
///   about, so a rescued story keeps its name, chapter and people.
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
    /// "Keep going" didn't work because the iPhone is still busy, for
    /// example with a call.
    private(set) var couldNotResume = false
    /// Which family clip is being recorded, so its row shows it even if the
    /// row is drawn again.
    private(set) var clipName: String?

    /// Called once if the recording has to stop to protect the story.
    var onMustStop: (@MainActor (StopReason) -> Void)?

    let safetyLimit: TimeInterval = 2 * 60 * 60
    /// Needed to start: about 30 minutes of raw audio plus room to convert it.
    let bytesNeededToStart: Int64 = 250_000_000

    /// Below this while recording, stop and save what there is. Finishing
    /// needs room for the compact copy and for storing it (about a fifth of
    /// the raw recording), so a long story needs more.
    static func bytesNeededToContinue(afterRecording seconds: TimeInterval) -> Int64 {
        let rawBytes = seconds * rawBytesPerSecond
        return max(150_000_000, Int64(rawBytes * 0.2))
    }

    /// 16-bit mono at 44.1 kHz.
    nonisolated static let rawBytesPerSecond: Double = 88_200

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var fileURL: URL?
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var spaceCheck: Task<Void, Never>?
    @ObservationIgnored private var conversion: Task<FinishedRecording, Error>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var ticks = 0
    /// Ticks in a row where the microphone had stopped by itself.
    @ObservationIgnored private var stoppedTicks = 0
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

    /// Free space for important data, in bytes. It can take a moment, so
    /// it's asked off the main thread while recording.
    nonisolated static func availableCapacity() -> Int64? {
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

    /// Starts recording. For a story, `note` is written next to the
    /// recording so a rescued story knows what it was about.
    func start(kind: Kind = .story, note: RecordingNote? = nil, clipName: String? = nil) async throws {
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

        let directory = kind == .story ? Self.inProgressDirectory : Self.clipsDirectory
        let url = directory.appendingPathComponent("\(UUID().uuidString).caf")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder: AVAudioRecorder
        do {
            try AudioSessionController.activateForRecording()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            AudioSessionController.finishRecording()
            throw RecorderError.couldNotStart
        }
        recorder.isMeteringEnabled = true
        recorder.delegate = events
        guard recorder.prepareToRecord(), recorder.record() else {
            recorder.delegate = nil
            AudioSessionController.finishRecording()
            throw RecorderError.couldNotStart
        }

        self.recorder = recorder
        fileURL = url
        elapsed = 0
        level = 0
        ticks = 0
        stoppedTicks = 0
        hasAskedToStop = false
        couldNotResume = false
        self.clipName = kind == .clip ? clipName : nil
        state = .recording
        if kind == .story, let note {
            note.write(besideRecordingAt: url)
        }
        ScreenAwake.set(.recording, true)
        observeInterruptions()
        startMetering()
    }

    /// Picks up again after an interruption. If the iPhone is still busy
    /// (a call hasn't ended yet), it stays paused and says so.
    func resume() {
        guard state == .interrupted, let recorder else { return }
        do {
            try AudioSessionController.activateForRecording()
            guard recorder.record() else {
                couldNotResume = true
                return
            }
            couldNotResume = false
            stoppedTicks = 0
            state = .recording
        } catch {
            couldNotResume = true
        }
    }

    /// Stops and returns the finished recording (converted to `.m4a`).
    ///
    /// Throws `CancellationError` if the phone was locked and the time to
    /// finish ran out: the recording then stays on disk, whole, and becomes
    /// a story the next time the app opens.
    func finish() async throws -> FinishedRecording {
        guard let recorder, let url = fileURL, state != .finishing else {
            throw RecorderError.nothingRecorded
        }
        state = .finishing
        // Asked for first, while the microphone still keeps the app running,
        // in case the phone is locked right now.
        let activity = BackgroundActivity("Finish a story") { [weak self] in
            self?.conversion?.cancel()
        }
        defer { activity.end() }
        let measured = recorder.currentTime > 0 ? recorder.currentTime : elapsed
        recorder.stop()
        tearDown()

        let conversion = Task {
            try await AudioConverter.finalizeRecording(at: url, measuredDuration: measured)
        }
        self.conversion = conversion
        let result = await conversion.result
        self.conversion = nil

        state = .idle
        elapsed = 0
        level = 0
        clipName = nil
        return try result.get()
    }

    /// A family clip that's no longer wanted (its editor was closed): it's
    /// stopped and thrown away. Never used for his stories.
    func discardClip() async {
        guard clipName != nil, state == .recording || state == .interrupted else { return }
        if let finished = try? await finish() {
            try? FileManager.default.removeItem(at: finished.fileURL)
        }
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
        spaceCheck?.cancel()
        spaceCheck = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        recorder?.delegate = nil
        recorder = nil
        fileURL = nil
        couldNotResume = false
        ScreenAwake.set(.recording, false)
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
            stoppedTicks = 0
            return
        }
        if !recorder.isRecording {
            // A call stops the microphone a moment before the app hears
            // about it, so only a stop that lasts a whole second means the
            // system stopped it for good (for example, the disk filled).
            stoppedTicks += 1
            level = 0
            if stoppedTicks >= 10 {
                askToStop(.systemStopped)
            }
            return
        }
        stoppedTicks = 0
        recorder.updateMeters()
        let power = Double(recorder.averagePower(forChannel: 0))
        level = max(0, min(1, (power + 50) / 50))
        elapsed = recorder.currentTime

        ticks += 1
        if ticks % 50 == 0 {
            checkSpace()
        }
        if elapsed >= safetyLimit {
            askToStop(.safetyLimit)
        }
    }

    /// Checks the free space off the main thread, so the screen never stutters.
    private func checkSpace() {
        guard spaceCheck == nil else { return }
        let needed = Self.bytesNeededToContinue(afterRecording: elapsed)
        spaceCheck = Task { [weak self] in
            let free = await Task.detached(priority: .utility) {
                StoryRecorder.availableCapacity()
            }.value
            guard let self, !Task.isCancelled else { return }
            self.spaceCheck = nil
            if let free, free < needed {
                self.askToStop(.storageAlmostFull)
            }
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
            if state == .recording {
                state = .interrupted
                level = 0
            }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            // Only while he's looking at the app: a locked phone must never
            // start recording the room by itself after a call.
            if options.contains(.shouldResume), UIApplication.shared.applicationState == .active {
                resume()
            }
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
