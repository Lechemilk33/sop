import AVFoundation
import Observation

/// Reads a question out loud when he taps "Read it to me". If a family member
/// recorded the question in their own voice, that recording plays instead.
/// A call, or taking out headphones, stops the reading.
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
    @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
    @ObservationIgnored private var events: AudioSessionEvents?
    /// The voice chosen for each language, worked out once.
    @ObservationIgnored private var voices: [String: AVSpeechSynthesisVoice] = [:]

    init() {
        synthesizer.delegate = speechRelay
        speechRelay.onFinish = { [weak self] finished in
            guard let self, finished === self.currentUtterance else { return }
            self.currentUtterance = nil
            self.isReading = false
        }
        clipRelay.onFinish = { [weak self] finished, _ in
            guard let self, finished === self.clipPlayer else { return }
            self.clipPlayer = nil
            self.isReading = false
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
        utterance.voice = voice()
        // A little slower than normal, with a short pause before starting.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.preUtteranceDelay = 0.2
        currentUtterance = utterance
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

    private func voice() -> AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        if let known = voices[language] {
            return known
        }
        let chosen = Self.bestVoice(for: language)
        voices[language] = chosen
        return chosen
    }

    /// A calm, natural voice in his own language and accent. Novelty voices
    /// (like "Bubbles"), robotic Eloquence voices and Personal Voice are never
    /// used. A downloaded Enhanced or Premium voice wins; otherwise it's the
    /// iPhone's usual voice for the language.
    private static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
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

/// Forwards "finished speaking" from AVSpeechSynthesizer to the main actor,
/// with the utterance itself, so it's compared by identity and a finished
/// one can never be mistaken for a new one.
final class SpeechFinishRelay: NSObject, AVSpeechSynthesizerDelegate {
    /// Set once on the main actor when the reader is created, then only read.
    nonisolated(unsafe) var onFinish: (@MainActor (AVSpeechUtterance) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        notify(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        notify(utterance)
    }

    private func notify(_ utterance: AVSpeechUtterance) {
        let handler = onFinish
        nonisolated(unsafe) let finished = utterance
        Task { @MainActor in handler?(finished) }
    }
}
