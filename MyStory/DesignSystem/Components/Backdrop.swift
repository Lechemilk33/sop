import SwiftUI

/// The calm background behind his screens: a soft warm gradient with a faint
/// glow of the place's color in the top corner, so the glass has something
/// gentle to catch. There is no pattern and nothing moves. The glow is faint
/// enough that soft text and button edges over it keep their contrast, and
/// it stays away from the buttons at the bottom.
struct Backdrop: View {
    var tone: Tone?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.paper, Palette.paperDeep], startPoint: .top, endPoint: .bottom)
            if let tone {
                RadialGradient(
                    colors: [tone.accent.opacity(0.07), .clear],
                    center: .topTrailing,
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
            RadialGradient(colors: [Palette.brick.opacity(0.06), .clear], center: .topTrailing, startRadius: 0, endRadius: 400)
            RadialGradient(colors: [Palette.marigold.opacity(0.07), .clear], center: .leading, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

extension EnvironmentValues {
    /// The place the current screen belongs to: Tell (brick), People (blue)
    /// or Stories (gold). Set by `RootView`; tints the background.
    @Entry var placeTone: Tone? = nil
}
