import AVFoundation
import Observation
import SwiftData

/// Plays his stories, one at a time or one after another ("Play them all").
@MainActor
@Observable
final class StoryPlayer {
    private(set) var currentStory: Story?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    /// The last story (or the whole list) has finished.
    private(set) var hasFinished = false
    /// The story's recording couldn't be played.
    private(set) var couldNotPlay = false

    var progress: Double {
        duration > 0 ? min(1, currentTime / duration) : 0
    }

    @ObservationIgnored private var queue: [Story] = []
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var player: AVAudioPlayer?
    private let relay = PlayerFinishRelay()
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    /// Changes whenever playback is stopped or restarted, so a pending
    /// "next story" never starts after he has left the screen.
    @ObservationIgnored private var generation = 0
    /// The story paused while he looks at "About this story", so coming back
    /// carries on where it was instead of starting over.
    @ObservationIgnored private var heldStoryID: PersistentIdentifier?

    /// Whether a story is paused and waiting for him to come back to it.
    var isHolding: Bool {
        heldStoryID != nil
    }

    init() {
        relay.onFinish = { [weak self] _ in
            self?.handleFinish()
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                // A phone call pauses the story. He taps Play to carry on.
                if typeValue == AVAudioSession.InterruptionType.began.rawValue {
                    self?.pauseForInterruption()
                }
            }
        }
    }

    /// Plays the stories in order, starting at `startIndex`.
    func play(_ stories: [Story], startingAt startIndex: Int = 0) {
        guard !stories.isEmpty else { return }
        let startAt = min(max(0, startIndex), stories.count - 1)
        stop()
        queue = stories
        index = startAt
        start(queue[index])
    }

    func togglePlayPause() {
        guard let player else {
            if let currentStory { start(currentStory) }
            return
        }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopProgressUpdates()
        } else {
            if hasFinished {
                player.currentTime = 0
                currentTime = 0
                hasFinished = false
            }
            AudioSessionController.activateForPlayback()
            if player.play() {
                isPlaying = true
                startProgressUpdates()
            }
        }
    }

    /// Pauses the story before he opens "About this story". The next story
    /// in a "Play them all" list waits too.
    func holdWhileOrganizing() {
        generation += 1
        pauseForInterruption()
        heldStoryID = currentStory?.persistentModelID
    }

    /// Coming back from "About this story": true if the paused story is still
    /// here to carry on with. Either way, the hold is over.
    func resumeHold() -> Bool {
        defer { heldStoryID = nil }
        guard let heldStoryID, let currentStory else { return false }
        return currentStory.persistentModelID == heldStoryID
    }

    /// Stops and forgets everything, so no screen can show a story that the
    /// family may since have deleted.
    func stop() {
        heldStoryID = nil
        generation += 1
        stopProgressUpdates()
        player?.stop()
        player = nil
        isPlaying = false
        currentStory = nil
        queue = []
        index = 0
        currentTime = 0
        duration = 0
        hasFinished = false
        couldNotPlay = false
    }

    // MARK: - Private

    private func start(_ story: Story) {
        generation += 1
        stopProgressUpdates()
        player?.stop()
        player = nil
        currentStory = story
        hasFinished = false
        couldNotPlay = false
        currentTime = 0
        duration = story.duration
        guard let data = story.audioData, let newPlayer = try? AVAudioPlayer(data: data) else {
            couldNotPlay = true
            hasFinished = true
            isPlaying = false
            return
        }
        AudioSessionController.activateForPlayback()
        newPlayer.delegate = relay
        newPlayer.prepareToPlay()
        player = newPlayer
        duration = newPlayer.duration
        guard newPlayer.play() else {
            couldNotPlay = true
            hasFinished = true
            isPlaying = false
            return
        }
        isPlaying = true
        story.playCount += 1
        story.lastPlayedAt = Date()
        startProgressUpdates()
    }

    private func pauseForInterruption() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        stopProgressUpdates()
    }

    private func handleFinish() {
        stopProgressUpdates()
        isPlaying = false
        currentTime = duration
        guard index + 1 < queue.count else {
            hasFinished = true
            return
        }
        index += 1
        let next = queue[index]
        let token = generation
        Task { [weak self] in
            // A short, calm pause between stories.
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.generation == token else { return }
            self.start(next)
        }
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let player = self.player {
                    self.currentTime = player.currentTime
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }
}
