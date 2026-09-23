import SwiftUI

/// The bar at the top of his screens. Home is always in the top-right corner,
/// and the way back always says where it goes ("My people", not just an arrow).
struct TopBar: View {
    let backTitle: String?
    let onBack: () -> Void
    let onHome: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                backButton
                Spacer(minLength: 12)
                homeButton
            }
            VStack(alignment: .leading, spacing: 10) {
                homeButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                backButton
            }
        }
    }

    @ViewBuilder
    private var backButton: some View {
        if let backTitle {
            NavPill(title: backTitle, systemImage: Symbols.back, accessibilityText: "Back to \(backTitle)", action: onBack)
        }
    }

    private var homeButton: some View {
        NavPill(title: "Home", systemImage: Symbols.home, accessibilityText: "Home", action: onHome)
    }
}

/// A labeled navigation button, at least 60 pt tall.
struct NavPill: View {
    let title: String
    let systemImage: String
    let accessibilityText: String
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .accessibilityHidden(true)
                Text(title)
                    .appFont(.compactButton)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: Metrics.navButtonHeight)
            .background(shape.fill(Palette.card))
            .overlay(shape.strokeBorder(contrast == .increased ? Palette.ink : Palette.edge, lineWidth: Metrics.tappableBorder))
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityLabel(Text(accessibilityText))
    }
}
