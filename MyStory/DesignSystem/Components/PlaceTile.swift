import SwiftUI

/// One of the big choices on Home: a frosted glass tile with the place's
/// medallion, a name, a few words about what's inside, and a chevron.
struct PlaceTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tone: Tone
    var minHeight: CGFloat = Metrics.heroButtonHeight
    let action: () -> Void

    var body: some View {
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 18) {
                Medallion(systemImage: systemImage, tone: tone, size: 64)
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
                Spacer(minLength: 8)
                RowChevron()
            }
        }
        .buttonStyle(GlassActionStyle(
            tone: .outline,
            minHeight: minHeight,
            cornerRadius: Metrics.heroCornerRadius,
            alignment: .leading,
            wash: tone.tint.opacity(0.55)
        ))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title). \(subtitle)"))
        .accessibilityAddTraits(.isButton)
    }
}
