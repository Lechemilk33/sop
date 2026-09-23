import AVFoundation

/// One place that decides how the app uses audio. Playback ignores the ring/
/// silent switch, so a story is never silently muted.
enum AudioSessionController {
    static func configureForPlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
    }

    static func activateForPlayback() {
        configureForPlayback()
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    static func finishRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        configureForPlayback()
    }
}

/// Forwards "finished playing" from AVAudioPlayer to the main actor.
final class PlayerFinishRelay: NSObject, AVAudioPlayerDelegate {
    var onFinish: (@MainActor (Bool) -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let handler = onFinish
        Task { @MainActor in handler?(flag) }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let handler = onFinish
        Task { @MainActor in handler?(false) }
    }
}
