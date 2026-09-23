import AVFoundation
import Observation

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

    var progress: Double {
        duration > 0 ? min(1, currentTime / duration) : 0
    }

    @ObservationIgnored private var queue: [Story] = []
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var player: AVAudioPlayer?
    private let relay = PlayerFinishRelay()
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    /// Changes whenever playback is stopped or restarted, so a pending
    /// "next story" never starts after he has left the screen.
    @ObservationIgnored private var generation = 0

    init() {
        relay.onFinish = { [weak self] _ in
            self?.handleFinish()
        }
    }

    /// Plays the stories in order, starting at `startIndex`.
    func play(_ stories: [Story], startingAt startIndex: Int = 0) {
        guard !stories.isEmpty else { return }
        queue = stories
        index = min(max(0, startIndex), stories.count - 1)
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
            player.play()
            isPlaying = true
            startProgressUpdates()
        }
    }

    func stop() {
        generation += 1
        stopProgressUpdates()
        player?.stop()
        player = nil
        isPlaying = false
    }

    // MARK: - Private

    private func start(_ story: Story) {
        stop()
        currentStory = story
        hasFinished = false
        currentTime = 0
        duration = story.duration
        guard let data = story.audioData, let newPlayer = try? AVAudioPlayer(data: data) else {
            hasFinished = true
            return
        }
        AudioSessionController.activateForPlayback()
        newPlayer.delegate = relay
        newPlayer.prepareToPlay()
        newPlayer.play()
        player = newPlayer
        duration = newPlayer.duration
        isPlaying = true
        story.playCount += 1
        story.lastPlayedAt = Date()
        startProgressUpdates()
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
