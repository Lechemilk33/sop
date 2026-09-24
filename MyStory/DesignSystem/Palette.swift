import SwiftUI

/// Every color in the app. Calm, warm neutrals with one deep color per place,
/// used for small accents rather than big blocks, so it reads as grown-up.
/// Values and reasons are in PLAN.md → "Look and feel".
///
/// - Text is near-black on warm white (13:1 or more). Soft ink is 7.2:1 or
///   more everywhere it's used, including over the soft place glow.
/// - Anything tappable has an edge of at least 3.5:1 against what's behind it.
/// - White words on colored buttons are almost 9:1 on the solid color, so
///   they stay above 7:1 even where the glass lightens it by 7%.
/// - The three places (Tell, People, Stories) differ in lightness as well as
///   hue, because Alzheimer's weakens contrast perception and blue–green
///   judgments: brick L*31, navy L*20, gold L*71.
enum Palette {
    /// The background gradient, top to bottom.
    static let paper = Color(hex: 0xF5F1EB)
    static let paperDeep = Color(hex: 0xE8E1D7)
    static let card = Color.white

    static let ink = Color(hex: 0x1C1A17)
    static let softInk = Color(hex: 0x443E39)
    /// Edge of anything tappable.
    static let edge = Color(hex: 0x766B5F)
    /// Soft edge of things that can't be tapped.
    static let hairline = Color(hex: 0xDCD4C9)

    /// Tell a story.
    static let brick = Color(hex: 0x842C18)
    static let brickTint = Color(hex: 0xF3DDD5)
    /// My people. Deep navy, so it differs from brick in lightness.
    static let blue = Color(hex: 0x122F5C)
    static let blueTint = Color(hex: 0xDCE4EF)
    /// My stories. Light gold with dark ink on it.
    static let marigold = Color(hex: 0xE0A33A)
    /// Text and icons on gold tints.
    static let marigoldRim = Color(hex: 0x6E4B0E)
    static let marigoldTint = Color(hex: 0xF5E6C8)
    static let green = Color(hex: 0x1E5530)
    static let greenTint = Color(hex: 0xDCEADF)

    static let photoBackdrop = Color(hex: 0xE6DFD4)
    static let photoFigure = Color(hex: 0x9A9084)
}

/// The colors for each kind of button and place.
enum Tone {
    case brick
    case blue
    case marigold
    case green
    case ink
    /// A quiet button: frosted glass with dark words.
    case outline

    /// The solid color under a prominent button's glass.
    var fill: Color {
        switch self {
        case .brick: Palette.brick
        case .blue: Palette.blue
        case .marigold: Palette.marigold
        case .green: Palette.green
        case .ink: Palette.ink
        case .outline: .clear
        }
    }

    var foreground: Color {
        switch self {
        case .marigold, .outline: Palette.ink
        case .brick, .blue, .green, .ink: .white
        }
    }

    /// The place's color for icons and medallions.
    var accent: Color {
        switch self {
        case .brick: Palette.brick
        case .blue: Palette.blue
        case .marigold: Palette.marigold
        case .green: Palette.green
        case .ink, .outline: Palette.ink
        }
    }

    /// The color of an icon sitting on `accent`.
    var onAccent: Color {
        self == .marigold ? Palette.ink : .white
    }

    /// A pale version of the place's color.
    var tint: Color {
        switch self {
        case .brick: Palette.brickTint
        case .blue: Palette.blueTint
        case .marigold: Palette.marigoldTint
        case .green: Palette.greenTint
        case .ink, .outline: Palette.hairline
        }
    }

    var isProminent: Bool {
        self != .outline
    }
}

extension Color {
    /// Creates an sRGB color from a 24-bit hex value such as `0xFBF5EA`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
