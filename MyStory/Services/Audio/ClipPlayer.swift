import AVFoundation
import Observation

/// Plays short clips: a family member's recorded hello, or a question read in
/// their own voice. One clip at a time.
@MainActor
@Observable
final class ClipPlayer {
    /// Identifies the clip that is playing, if any.
    private(set) var playingID: String?

    @ObservationIgnored private var player: AVAudioPlayer?
    private let relay = PlayerFinishRelay()

    init() {
        relay.onFinish = { [weak self] _ in
            self?.playingID = nil
            self?.player = nil
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
        AudioSessionController.activateForPlayback()
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
