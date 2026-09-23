import AVFoundation
import Observation

/// Reads a question out loud when he taps "Read it to me". If a family member
/// recorded the question in their own voice, that recording plays instead.
@MainActor
@Observable
final class QuestionReader {
    private(set) var isReading = false

    private let synthesizer = AVSpeechSynthesizer()
    private let speechRelay = SpeechFinishRelay()
    private let clipRelay = PlayerFinishRelay()
    @ObservationIgnored private var clipPlayer: AVAudioPlayer?
    /// The utterance being spoken, so a late "cancelled" from an earlier one
    /// can't switch the button back while a new one is playing.
    @ObservationIgnored private var currentUtterance: ObjectIdentifier?

    init() {
        synthesizer.delegate = speechRelay
        speechRelay.onFinish = { [weak self] finished in
            guard let self, self.currentUtterance == finished else { return }
            self.currentUtterance = nil
            self.isReading = false
        }
        clipRelay.onFinish = { [weak self] _ in
            self?.isReading = false
            self?.clipPlayer = nil
        }
    }

    func toggle(text: String, recordedAudio: Data?) {
        if isReading {
            stop()
        } else {
            read(text: text, recordedAudio: recordedAudio)
        }
    }

    func read(text: String, recordedAudio: Data?) {
        stop()
        AudioSessionController.activateForPlayback()
        if let recordedAudio, let player = try? AVAudioPlayer(data: recordedAudio) {
            player.delegate = clipRelay
            player.prepareToPlay()
            if player.play() {
                clipPlayer = player
                isReading = true
                return
            }
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice()
        // A little slower than normal, with a short pause before starting.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.preUtteranceDelay = 0.2
        currentUtterance = ObjectIdentifier(utterance)
        isReading = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        clipPlayer?.stop()
        clipPlayer = nil
        currentUtterance = nil
        isReading = false
    }

    /// The most natural installed voice for the current language.
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let prefix = String(language.prefix(2))
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
        let best = candidates.max { lhs, rhs in
            if lhs.quality != rhs.quality { return lhs.quality.rawValue < rhs.quality.rawValue }
            // Prefer the exact regional voice, e.g. en-US over en-GB.
            return lhs.language != language && rhs.language == language
        }
        return best ?? AVSpeechSynthesisVoice(language: language)
    }
}

/// Forwards "finished speaking" from AVSpeechSynthesizer to the main actor.
final class SpeechFinishRelay: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (@MainActor (ObjectIdentifier) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        notify(ObjectIdentifier(utterance))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        notify(ObjectIdentifier(utterance))
    }

    private func notify(_ utterance: ObjectIdentifier) {
        let handler = onFinish
        Task { @MainActor in handler?(utterance) }
    }
}
