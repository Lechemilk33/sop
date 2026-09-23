import SwiftUI

/// The microphone on the listening screen. It is a soft tinted circle, not a
/// solid one, so it reads as "listening" rather than as a button. Its halo
/// grows with his voice, so he can see the app is hearing him. With Reduce
/// Motion on, the halo stays still.
struct ListeningIndicator: View {
    /// Voice level from 0 to 1.
    let level: Double
    let isListening: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let halo = reduceMotion || !isListening ? 0 : level
        ZStack {
            Circle()
                .fill(Palette.brick.opacity(isListening ? 0.18 : 0.08))
                .frame(width: 164 + 76 * halo, height: 164 + 76 * halo)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: halo)
            Circle()
                .fill(Palette.brickTint)
                .frame(width: 164, height: 164)
            Image(systemName: isListening ? Symbols.tell : Symbols.pause)
                .font(.system(size: 66, weight: .bold))
                .foregroundStyle(isListening ? Palette.brick : Palette.softInk)
        }
        .frame(width: 240, height: 240)
        .accessibilityHidden(true)
    }
}

/// A thick, non-interactive progress bar. There is nothing to drag.
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
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}
