import SwiftUI

/// A white card with a soft outline for things that can't be tapped. Things
/// that can be tapped always have the strong outline instead.
struct InfoCard<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Palette.card))
        .overlay(shape.strokeBorder(Palette.hairline, lineWidth: Metrics.staticBorder))
    }
}

/// A calm message for an empty screen, always paired with something to do.
struct EmptyStateMessage: View {
    let title: String
    let message: String

    var body: some View {
        InfoCard {
            Text(title)
                .appFont(.subtitle)
                .foregroundStyle(Palette.ink)
            Text(message)
                .appFont(.body)
                .foregroundStyle(Palette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
