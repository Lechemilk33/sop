import SwiftUI

/// How tall a button is and how big its words are.
enum ButtonSize {
    /// The three choices on the home screen.
    case hero
    /// The main action on a screen, like "Start talking".
    case large
    case regular
    case compact

    var minHeight: CGFloat {
        switch self {
        case .hero: Metrics.heroButtonHeight
        case .large: Metrics.largeButtonHeight
        case .regular: Metrics.buttonHeight
        case .compact: Metrics.compactButtonHeight
        }
    }

    var textStyle: AppTextStyle {
        switch self {
        case .hero: .heroButton
        case .large: .largeButton
        case .regular: .button
        case .compact: .compactButton
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .hero: 44
        case .large: 40
        case .regular: 32
        case .compact: 26
        }
    }

    var cornerRadius: CGFloat {
        self == .hero ? Metrics.heroCornerRadius : Metrics.cornerRadius
    }
}

/// A full-width button with an icon and a word. Every tappable action in his
/// part of the app uses this, so buttons always look like buttons, always
/// carry a label, and ignore accidental double taps.
struct BigButton: View {
    private let title: String
    private let systemImage: String
    private let tone: Tone
    private let size: ButtonSize
    private let action: () -> Void

    @ScaledMetric(relativeTo: .title) private var iconScale: CGFloat = 1
    @Environment(\.textScale) private var textScale

    init(
        _ title: String,
        systemImage: String,
        tone: Tone = .outline,
        size: ButtonSize = .regular,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.size = size
        self.action = action
    }

    var body: some View {
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: min(size.iconSize * iconScale * textScale, size.iconSize * 1.8), weight: .bold))
                    .frame(minWidth: size.iconSize + 8)
                    .accessibilityHidden(true)
                Text(title)
                    .appFont(size.textStyle)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(FilledButtonStyle(tone: tone, minHeight: size.minHeight, cornerRadius: size.cornerRadius))
        .accessibilityLabel(Text(title))
    }
}

/// Solid (or outlined) rounded shape with a strong rim. Pressing darkens it a
/// little, without moving anything.
struct FilledButtonStyle: ButtonStyle {
    let tone: Tone
    var minHeight: CGFloat = Metrics.buttonHeight
    var cornerRadius: CGFloat = Metrics.cornerRadius
    var alignment: Alignment = .leading

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return configuration.label
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .background(shape.fill(tone.fill))
            .overlay(shape.strokeBorder(tone.rim, lineWidth: contrast == .increased ? 4 : Metrics.tappableBorder))
            .overlay(shape.fill(Palette.ink.opacity(configuration.isPressed ? 0.14 : 0)))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Used for tappable cards and pills: dims slightly while pressed.
struct PressDimStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(Color.black.opacity(configuration.isPressed ? 0.06 : 0).allowsHitTesting(false))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
