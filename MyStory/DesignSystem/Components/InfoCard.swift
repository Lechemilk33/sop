import SwiftUI

/// A white card with a soft edge and shadow for things that can't be tapped.
/// Things that can be tapped always have the stronger edge instead.
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
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Palette.card))
        .overlay(shape.strokeBorder(Palette.hairline, lineWidth: Metrics.staticBorder))
        .shadow(color: Palette.ink.opacity(0.05), radius: 12, y: 4)
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

/// A short line under a screen's title that says what to do here.
struct Instruction: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .appFont(.bodyBold)
            .foregroundStyle(Palette.softInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
