import SwiftUI

/// How tall a button is and how big its words are.
enum ButtonSize {
    /// The main choices on Home.
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
        case .hero: 34
        case .large: 30
        case .regular: 26
        case .compact: 22
        }
    }

    var cornerRadius: CGFloat {
        self == .hero ? Metrics.heroCornerRadius : Metrics.cornerRadius
    }
}

/// A full-width Liquid Glass button with an icon and a word. Every action in
/// his part of the app uses this, so buttons always look like buttons, always
/// carry a label, and ignore accidental double taps.
///
/// Colored tones are the main action on a screen: solid color under the
/// glass, so white words keep 7:1 contrast. `.outline` is a quiet frosted
/// button with dark words and a visible edge.
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
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: min(size.iconSize * iconScale * textScale, size.iconSize * 1.8), weight: .semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .appFont(size.textStyle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassActionStyle(tone: tone, minHeight: size.minHeight, cornerRadius: size.cornerRadius))
        .accessibilityLabel(Text(title))
    }
}

/// The look of every button on his screens: Liquid Glass that responds to
/// touch. Prominent tones sit on a solid color so their words stay legible
/// on any background; quiet ones are frosted with a clear edge. Pressing
/// darkens the button a little, without moving anything.
struct GlassActionStyle: ButtonStyle {
    let tone: Tone
    var minHeight: CGFloat = Metrics.buttonHeight
    var cornerRadius: CGFloat = Metrics.cornerRadius
    var alignment: Alignment = .center
    /// A pale wash for quiet buttons, like the place colors on Home's tiles.
    var wash: Color?

    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return configuration.label
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .contentShape(shape)
            .glassEffect(glass, in: shape)
            .background {
                if tone.isProminent {
                    shape.fill(tone.fill)
                }
            }
            .overlay {
                if let edge {
                    shape.strokeBorder(edge, lineWidth: edgeWidth)
                }
            }
            .overlay {
                shape.fill(Palette.ink.opacity(configuration.isPressed ? 0.1 : 0))
                    .allowsHitTesting(false)
            }
    }

    private var glass: Glass {
        if tone.isProminent {
            return Glass.regular.tint(tone.fill).interactive()
        }
        if let wash {
            return Glass.regular.tint(wash).interactive()
        }
        return Glass.regular.interactive()
    }

    /// Dark colors are their own edge. Gold and frosted buttons get one, so
    /// the button's shape is at least 3:1 against the background.
    private var edge: Color? {
        if contrast == .increased { return Palette.ink }
        switch tone {
        case .outline: return Palette.edge
        case .marigold: return Palette.marigoldRim
        case .brick, .blue, .green, .ink: return nil
        }
    }

    private var edgeWidth: CGFloat {
        contrast == .increased ? Metrics.increasedContrastBorder : Metrics.tappableBorder
    }
}

/// Used for tappable cards: dims slightly while pressed.
struct PressDimStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(Color.black.opacity(configuration.isPressed ? 0.06 : 0).allowsHitTesting(false))
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}
