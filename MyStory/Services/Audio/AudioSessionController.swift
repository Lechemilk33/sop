import AVFoundation

/// One place that decides how the app uses audio. Playback ignores the ring/
/// silent switch, so a story is never silently muted.
enum AudioSessionController {
    static func configureForPlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
    }

    /// False if the iPhone won't play right now, for example during a call.
    @discardableResult
    static func activateForPlayback() -> Bool {
        configureForPlayback()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            return true
        } catch {
            return false
        }
    }

    static func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        // Every tap is felt, even while the microphone is on.
        try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true)
    }

    static func finishRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        configureForPlayback()
    }
}

/// What the iPhone tells the app about its sound. Every player listens, so
/// nothing carries on playing out loud by surprise.
@MainActor
final class AudioSessionEvents {
    enum Event {
        /// A call, an alarm or another app took over the sound.
        case interruptionBegan
        /// It's over. `shouldResume` means the iPhone expects the sound to
        /// carry on, as after a Siri announcement.
        case interruptionEnded(shouldResume: Bool)
        /// Headphones, AirPods or a car's speakers went away, so the sound
        /// would move to the iPhone's own speaker.
        case outputLost
        /// The iPhone's audio system restarted; players must be made again.
        case servicesReset
    }

    /// Lives as long as the player that owns it, which is the whole time the
    /// app runs, so the observers are never removed.
    private var observers: [NSObjectProtocol] = []

    init(_ handler: @escaping @MainActor @Sendable (Event) -> Void) {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        // The interruption and reset notifications come on the main thread;
        // route changes come on another thread, so `.main` moves them there.
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                switch typeValue.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) {
                case .began:
                    handler(.interruptionBegan)
                case .ended:
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
                    handler(.interruptionEnded(shouldResume: options.contains(.shouldResume)))
                default:
                    break
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated {
                if reasonValue == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    handler(.outputLost)
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                handler(.servicesReset)
            }
        })
    }
}

/// Forwards "finished playing" from AVAudioPlayer to the main actor, with the
/// player that finished, so a late message from an earlier player is never
/// taken for the one playing now.
final class PlayerFinishRelay: NSObject, AVAudioPlayerDelegate {
    var onFinish: (@MainActor (AVAudioPlayer, Bool) -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let handler = onFinish
        Task { @MainActor in handler?(player, flag) }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let handler = onFinish
        Task { @MainActor in handler?(player, false) }
    }
}
