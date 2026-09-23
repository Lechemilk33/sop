import SwiftUI

/// A screen's title with its place's colored tile ("Tell a story" in brick,
/// "My people" in blue, "My life" in marigold), so he always knows where he is.
struct SectionHeader: View {
    let title: String
    let systemImage: String
    let tone: Tone

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tone.foreground)
                .frame(width: 58, height: 58)
                .background(tile.fill(tone.fill))
                .overlay(tile.strokeBorder(tone.rim, lineWidth: Metrics.tappableBorder))
                .accessibilityHidden(true)
            Text(title)
                .appFont(.screenTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
