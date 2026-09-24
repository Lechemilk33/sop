import SwiftUI

/// A screen's title with its place's colored medallion ("Tell a story" in
/// brick, "My people" in navy, "My stories" in gold), so he always knows
/// where he is. The medallion has no edge, because an edge means "you can
/// tap this".
struct SectionHeader: View {
    let title: String
    let systemImage: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 16) {
            Medallion(systemImage: systemImage, tone: tone)
            Text(title)
                .appFont(.screenTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// A colored circle carrying an icon. Never tappable on its own.
struct Medallion: View {
    let systemImage: String
    let tone: Tone
    var size: CGFloat = Metrics.medallion

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tone.onAccent)
            .frame(width: size, height: size)
            .background(Circle().fill(tone.accent))
            .accessibilityHidden(true)
    }
}
