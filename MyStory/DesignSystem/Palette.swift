import SwiftUI

/// Every color in the app. Values and reasons are in PLAN.md → "Look and feel".
///
/// - Text is near-black on warm cream (15.8:1). Soft ink is still 8.3:1.
/// - Anything tappable has an outline of at least 3:1 against the background.
/// - The three places (Tell, People, Life) differ in lightness as well as hue,
///   because Alzheimer's weakens contrast perception and blue–green judgments.
enum Palette {
    static let paper = Color(hex: 0xFBF5EA)
    static let card = Color.white
    static let ink = Color(hex: 0x26190F)
    static let softInk = Color(hex: 0x574636)
    /// Outline of anything tappable.
    static let edge = Color(hex: 0x9C8466)
    /// Soft outline of things that can't be tapped.
    static let hairline = Color(hex: 0xDCCBB0)

    static let brick = Color(hex: 0x9F3118)
    static let blue = Color(hex: 0x1B4683)
    static let marigold = Color(hex: 0xF2B535)
    static let marigoldRim = Color(hex: 0x7A5410)
    static let marigoldTint = Color(hex: 0xF8E6B8)
    static let green = Color(hex: 0x276336)
    static let greenTint = Color(hex: 0xDDE9D6)

    static let photoBackdrop = Color(hex: 0xEADCC6)
    static let photoFigure = Color(hex: 0xA48C6C)
}

/// The fill, text and rim colors for each kind of button.
enum Tone {
    case brick
    case blue
    case marigold
    case green
    case ink
    case outline

    var fill: Color {
        switch self {
        case .brick: Palette.brick
        case .blue: Palette.blue
        case .marigold: Palette.marigold
        case .green: Palette.green
        case .ink: Palette.ink
        case .outline: Palette.card
        }
    }

    var foreground: Color {
        switch self {
        case .marigold, .outline: Palette.ink
        case .brick, .blue, .green, .ink: .white
        }
    }

    var rim: Color {
        switch self {
        case .brick: Palette.brick
        case .blue: Palette.blue
        case .marigold: Palette.marigoldRim
        case .green: Palette.green
        case .ink: Palette.ink
        case .outline: Palette.edge
        }
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
