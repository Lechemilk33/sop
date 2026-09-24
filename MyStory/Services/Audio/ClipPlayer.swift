import AVFoundation
import Observation

/// Plays short clips: a family member's recorded hello, or a question read in
/// their own voice. One clip at a time. A call, or taking out headphones,
/// stops the clip.
@MainActor
@Observable
final class ClipPlayer {
    /// Identifies the clip that is playing, if any.
    private(set) var playingID: String?

    @ObservationIgnored private var player: AVAudioPlayer?
    private let relay = PlayerFinishRelay()
    @ObservationIgnored private var events: AudioSessionEvents?

    init() {
        relay.onFinish = { [weak self] finished, _ in
            // A late message from a clip that was already replaced.
            guard let self, finished === self.player else { return }
            self.player = nil
            self.playingID = nil
        }
        events = AudioSessionEvents { [weak self] event in
            switch event {
            case .interruptionBegan, .outputLost, .servicesReset:
                self?.stop()
            case .interruptionEnded:
                break
            }
        }
    }

    func isPlaying(_ id: String) -> Bool {
        playingID == id
    }

    func toggle(id: String, data: Data?) {
        if playingID == id {
            stop()
        } else {
            play(id: id, data: data)
        }
    }

    func play(id: String, data: Data?) {
        stop()
        guard let data, let newPlayer = try? AVAudioPlayer(data: data) else { return }
        guard AudioSessionController.activateForPlayback() else { return }
        newPlayer.delegate = relay
        newPlayer.prepareToPlay()
        guard newPlayer.play() else { return }
        player = newPlayer
        playingID = id
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }
}
