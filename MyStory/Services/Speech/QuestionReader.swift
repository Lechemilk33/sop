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

    /// A calm, natural voice in his own language and accent. Novelty voices
    /// (like "Bubbles"), robotic Eloquence voices and Personal Voice are never
    /// used. A downloaded Enhanced or Premium voice wins; otherwise it's the
    /// iPhone's usual voice for the language.
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let natural = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language == language
                && !voice.voiceTraits.contains(.isNoveltyVoice)
                && !voice.voiceTraits.contains(.isPersonalVoice)
                && !voice.identifier.lowercased().contains("eloquence")
        }
        let downloaded = natural.filter { $0.quality == .premium || $0.quality == .enhanced }
        if let best = downloaded.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            return best
        }
        return AVSpeechSynthesisVoice(language: language)
    }
}

/// Forwards "finished speaking" from AVSpeechSynthesizer to the main actor.
final class SpeechFinishRelay: NSObject, AVSpeechSynthesizerDelegate {
    /// Set once on the main actor when the reader is created, then only read.
    nonisolated(unsafe) var onFinish: (@MainActor (ObjectIdentifier) -> Void)?

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
