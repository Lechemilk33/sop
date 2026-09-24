import AVFoundation
import MediaPlayer
import Observation
import SwiftData

/// Plays his stories, one at a time or one after another ("Play them all").
///
/// - A call or another app pauses the story, and it carries on by itself
///   when the iPhone says it should, as after a Siri announcement.
/// - Taking out headphones or AirPods pauses it, so his stories never play
///   out loud by surprise. AirPods, the Lock Screen and Control Center can
///   pause and play it.
/// - The screen stays on while a story plays, so he keeps seeing who's in
///   it and can read along; it can sleep once the story is paused.
/// - If the phone is locked, "Play them all" still goes on to the next story.
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

    /// Whether a story is paused and waiting for him to come back to it.
    var isHolding: Bool {
        heldStoryID != nil
    }

    @ObservationIgnored private var context: ModelContext?
    /// The stories to play, by ID, so one the family deletes meanwhile is
    /// simply skipped.
    @ObservationIgnored private var queue: [PersistentIdentifier] = []
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var player: AVAudioPlayer?
    private let relay = PlayerFinishRelay()
    @ObservationIgnored private var events: AudioSessionEvents?
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    /// Changes whenever playback is stopped, paused or restarted, so a
    /// pending "next story" never starts after he has left the screen.
    @ObservationIgnored private var generation = 0
    /// Between two stories of "Play them all": where the next one is.
    @ObservationIgnored private var upNext: Int?
    /// Keeps the app running through the pause between two stories if the
    /// phone is locked, so the next story still starts.
    @ObservationIgnored private var gapActivity: BackgroundActivity?
    /// Paused by a call or another app rather than by him.
    @ObservationIgnored private var pausedBySystem = false
    /// The story paused while he looks at "About this story", so coming back
    /// carries on where it was instead of starting over.
    @ObservationIgnored private var heldStoryID: PersistentIdentifier?

    init() {
        relay.onFinish = { [weak self] finished, _ in
            self?.handleFinish(of: finished)
        }
        events = AudioSessionEvents { [weak self] event in
            self?.handle(event)
        }
        setUpRemoteControls()
    }

    /// Plays the stories in order, starting at `startIndex`.
    func play(_ stories: [Story], startingAt startIndex: Int = 0) {
        guard !stories.isEmpty else { return }
        let startAt = min(max(0, startIndex), stories.count - 1)
        stop()
        context = stories[startAt].modelContext
        queue = stories.map(\.persistentModelID)
        startStory(at: startAt)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Plays or carries on: between two stories, the next one starts now.
    func play() {
        if upNext != nil {
            playNext()
            return
        }
        guard let player else {
            // The iPhone's audio restarted since; start the story again.
            if let story = context?.existing(currentStory) {
                begin(story)
            }
            return
        }
        guard !player.isPlaying else { return }
        cancelPending()
        if hasFinished {
            player.currentTime = 0
            currentTime = 0
            hasFinished = false
        }
        guard AudioSessionController.activateForPlayback(), player.play() else { return }
        pausedBySystem = false
        setPlaying(true)
        startProgressUpdates()
    }

    /// Pauses, or keeps a story that the iPhone already paused (for a call)
    /// paused, with its place remembered.
    func pause() {
        cancelPending()
        pausedBySystem = false
        stopProgressUpdates()
        if let player, player.isPlaying {
            player.pause()
            currentTime = player.currentTime
        }
        setPlaying(false)
    }

    /// Pauses the story before he opens "About this story". The next story
    /// in a "Play them all" list waits too.
    func holdWhileOrganizing() {
        pause()
        heldStoryID = currentStory?.persistentModelID
    }

    /// Coming back from "About this story": true if the paused story is still
    /// here to carry on with. If he opened it between two stories, the next
    /// one starts now. Either way, the hold is over.
    func resumeHold() -> Bool {
        defer { heldStoryID = nil }
        guard let heldStoryID, let currentStory, currentStory.persistentModelID == heldStoryID else { return false }
        if upNext != nil {
            playNext()
        }
        return true
    }

    /// Stops and forgets everything, so no screen can show a story that the
    /// family may since have deleted.
    func stop() {
        heldStoryID = nil
        cancelPending()
        upNext = nil
        pausedBySystem = false
        stopProgressUpdates()
        player?.stop()
        player = nil
        setPlaying(false)
        currentStory = nil
        context = nil
        queue = []
        index = 0
        currentTime = 0
        duration = 0
        hasFinished = false
        couldNotPlay = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Private

    /// Starts the story at `position`, skipping any the family has deleted.
    private func startStory(at position: Int) {
        var position = position
        while position < queue.count {
            if let story = story(withID: queue[position]) {
                index = position
                begin(story)
                return
            }
            position += 1
        }
        // Nothing left to play.
        setPlaying(false)
        if currentStory != nil {
            hasFinished = true
            updateNowPlaying()
        }
    }

    private func begin(_ story: Story) {
        // A next story that was waiting never starts over this one. The time
        // asked for between stories is handed back only once this one is
        // playing, so a locked phone can't be put to sleep in between.
        generation += 1
        let gap = gapActivity
        gapActivity = nil
        defer { gap?.end() }
        upNext = nil
        pausedBySystem = false
        stopProgressUpdates()
        player?.stop()
        player = nil
        setPlaying(false)
        currentStory = story
        hasFinished = false
        couldNotPlay = false
        currentTime = 0
        duration = story.duration
        guard let data = recording(of: story), let newPlayer = try? AVAudioPlayer(data: data) else {
            couldNotPlay = true
            hasFinished = true
            updateNowPlaying()
            return
        }
        newPlayer.delegate = relay
        newPlayer.prepareToPlay()
        player = newPlayer
        duration = newPlayer.duration
        // During a call the iPhone won't play; the story then waits for Play.
        guard AudioSessionController.activateForPlayback() else {
            updateNowPlaying()
            return
        }
        guard newPlayer.play() else {
            couldNotPlay = true
            hasFinished = true
            updateNowPlaying()
            return
        }
        story.playCount += 1
        story.lastPlayedAt = Date()
        setPlaying(true)
        startProgressUpdates()
    }

    private func handleFinish(of finished: AVAudioPlayer) {
        // A late message from a story that has already been replaced.
        guard finished === player else { return }
        stopProgressUpdates()
        currentTime = duration
        setPlaying(false)
        guard index + 1 < queue.count else {
            hasFinished = true
            updateNowPlaying()
            return
        }
        // A short, calm pause between stories. The screen stays on through it.
        upNext = index + 1
        generation += 1
        let token = generation
        gapActivity?.end()
        gapActivity = BackgroundActivity("Next story")
        ScreenAwake.set(.playing, true)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.generation == token else { return }
            self.playNext()
        }
    }

    /// Moves on only now, so a pause in between never skips a story.
    private func playNext() {
        guard let next = upNext else { return }
        let activity = gapActivity
        upNext = nil
        startStory(at: next)
        activity?.end()
    }

    /// Cancels a next story that's waiting to start (it stays up next).
    private func cancelPending() {
        generation += 1
        gapActivity?.end()
        gapActivity = nil
    }

    private func handle(_ event: AudioSessionEvents.Event) {
        switch event {
        case .interruptionBegan:
            // Playing, or in the pause before the next story.
            let wasGoing = isPlaying || gapActivity != nil
            pause()
            pausedBySystem = wasGoing
        case .interruptionEnded(let shouldResume):
            guard pausedBySystem else { return }
            pausedBySystem = false
            if shouldResume, !isHolding {
                play()
            }
        case .outputLost:
            // Paused, and it stays paused until he taps Play.
            pause()
        case .servicesReset:
            // Every player must be made again; he taps Play to carry on.
            pause()
            player = nil
            AudioSessionController.configureForPlayback()
        }
    }

    /// Reads the recording through a short-lived context, so the recordings
    /// of every story he has heard aren't all kept in memory.
    private func recording(of story: Story) -> Data? {
        guard let container = story.modelContext?.container else { return story.audioData }
        return ModelContext(container).existing(story)?.audioData
    }

    private func story(withID id: PersistentIdentifier) -> Story? {
        guard let context else { return nil }
        var descriptor = FetchDescriptor<Story>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func setPlaying(_ playing: Bool) {
        isPlaying = playing
        ScreenAwake.set(.playing, playing)
        updateNowPlaying()
    }

    // MARK: - Lock Screen, Control Center and AirPods

    private func setUpRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let currentStory else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentStory.displayTitle,
            MPMediaItemPropertyArtist: "My Story",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
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
