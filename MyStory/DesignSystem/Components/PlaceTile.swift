import SwiftUI

/// One of the big choices on Home: a frosted glass tile with a solid stripe
/// of the place's color down its side, the place's medallion, a name, a few
/// words about what's inside, and a chevron. The stripes and medallions
/// (brick, navy, gold) differ in lightness, so the three places look
/// different at a glance even when colors are hard to tell apart.
struct PlaceTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tone: Tone
    var minHeight: CGFloat = Metrics.heroButtonHeight
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.heroCornerRadius, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // With very large text the words go under the medallion,
                    // so they get the tile's whole width.
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Medallion(systemImage: systemImage, tone: tone, size: Metrics.tileMedallion)
                            Spacer(minLength: 8)
                            RowChevron()
                        }
                        words
                    }
                } else {
                    HStack(spacing: 18) {
                        Medallion(systemImage: systemImage, tone: tone, size: Metrics.tileMedallion)
                        words
                        Spacer(minLength: 8)
                        RowChevron()
                    }
                }
            }
            .padding(.leading, Metrics.tileStripe + 18)
            .padding(.trailing, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(alignment: .leading) {
                Rectangle()
                    .fill(tone.accent)
                    .frame(width: Metrics.tileStripe)
            }
            .clipShape(shape)
            .glassEffect(Glass.regular.tint(tone.tint.opacity(0.6)), in: shape)
            .overlay(
                shape.strokeBorder(
                    contrast == .increased ? Palette.ink : Palette.edge,
                    lineWidth: contrast == .increased ? Metrics.increasedContrastBorder : Metrics.tappableBorder
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title). \(subtitle)"))
        .accessibilityAddTraits(.isButton)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appFont(.tileTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
    }
}
