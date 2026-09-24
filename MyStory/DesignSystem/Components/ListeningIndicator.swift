import SwiftUI

/// The microphone on the listening screen. It is a soft tinted circle, not a
/// solid one, so it reads as "listening" rather than as a button. Its halo
/// grows with his voice, so he can see the app is hearing him. With Reduce
/// Motion on, the halo stays still. Paused, it shows a pause sign; while the
/// story is saved, a quiet microphone.
struct ListeningIndicator: View {
    /// Voice level from 0 to 1.
    let level: Double
    let isListening: Bool
    var isSaving = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let halo = reduceMotion || !isListening ? 0 : level
        ZStack {
            Circle()
                .fill(Palette.brick.opacity(isListening ? 0.12 : 0.05))
                .frame(width: 160 + 80 * halo, height: 160 + 80 * halo)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: halo)
            Circle()
                .fill(Palette.brickTint)
                .frame(width: 160, height: 160)
                .overlay(Circle().strokeBorder(Palette.brick.opacity(0.35), lineWidth: 1.5))
            Image(systemName: isListening || isSaving ? Symbols.tell : Symbols.pause)
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(isListening ? Palette.brick : Palette.softInk)
        }
        .frame(width: 240, height: 240)
        .accessibilityHidden(true)
    }
}

/// A calm, non-interactive progress bar. There is nothing to drag.
struct ProgressTrack: View {
    /// From 0 to 1.
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule()
                    .fill(Palette.marigoldRim)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}
