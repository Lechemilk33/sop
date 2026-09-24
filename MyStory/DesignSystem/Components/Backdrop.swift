import SwiftUI

/// The calm background behind his screens: a soft warm gradient with a faint
/// glow of the place's color in the corners, so each place feels a little
/// different and the glass has something gentle to catch. There is no
/// pattern and nothing moves. The glows are faint enough that soft text over
/// them still has 7:1 contrast.
struct Backdrop: View {
    var tone: Tone?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.paper, Palette.paperDeep], startPoint: .top, endPoint: .bottom)
            if let tone {
                RadialGradient(
                    colors: [tone.accent.opacity(0.08), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 460
                )
                RadialGradient(
                    colors: [tone.accent.opacity(0.06), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 420
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// Home's background: a faint glow of each of the three places.
struct HomeBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.paper, Palette.paperDeep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.brick.opacity(0.07), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Palette.blue.opacity(0.06), .clear], center: .trailing, startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Palette.marigold.opacity(0.08), .clear], center: .bottomLeading, startRadius: 0, endRadius: 440)
        }
        .ignoresSafeArea()
    }
}

extension EnvironmentValues {
    /// The place the current screen belongs to: Tell (brick), People (blue)
    /// or Stories (gold). Set by `RootView`; tints the background.
    @Entry var placeTone: Tone? = nil
}
