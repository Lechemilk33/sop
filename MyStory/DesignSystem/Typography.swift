import SwiftUI
import UIKit

/// The app's text styles. Sizes follow PLAN.md: nothing below 20 pt, reading
/// text at 22 pt, questions at 30 pt. Every style scales with the iPhone's
/// text size setting (Dynamic Type) and with the family's text size choice.
///
/// Text uses the iPhone's own font (San Francisco), which Apple designs for
/// legibility at every size. The family can switch to Atkinson Hyperlegible
/// ("Extra-clear letters"), designed for low vision, in Settings.
enum AppTextStyle {
    case greeting
    case screenTitle
    case personName
    case question
    case tileTitle
    case heroButton
    case largeButton
    case button
    case compactButton
    /// Text he types into a field, like a story's name.
    case field
    case subtitle
    case body
    case bodyBold
    case caption

    fileprivate var size: CGFloat {
        switch self {
        case .greeting: 36
        case .screenTitle: 34
        case .personName: 40
        case .question: 30
        case .tileTitle: 30
        case .heroButton: 32
        case .largeButton: 30
        case .button: 26
        case .compactButton: 22
        case .field: 26
        case .subtitle: 24
        case .body: 22
        case .bodyBold: 22
        case .caption: 20
        }
    }

    fileprivate var weight: AppFontWeight {
        switch self {
        case .greeting, .screenTitle, .personName, .tileTitle, .heroButton, .largeButton: .bold
        case .question, .button, .compactButton, .bodyBold, .field, .subtitle, .caption: .semibold
        case .body: .regular
        }
    }

    /// The Dynamic Type curve each style follows.
    fileprivate var scalingStyle: UIFont.TextStyle {
        switch self {
        case .greeting, .screenTitle, .personName: .largeTitle
        case .question, .tileTitle, .heroButton, .largeButton: .title1
        case .button, .field: .title2
        case .compactButton, .subtitle: .title3
        case .body, .bodyBold: .body
        case .caption: .callout
        }
    }

    func font(
        scale: CGFloat,
        dynamicTypeSize: DynamicTypeSize,
        boldText: Bool,
        extraClearLetters: Bool
    ) -> Font {
        let base = size * scale
        let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.uiContentSizeCategory)
        let scaled = UIFontMetrics(forTextStyle: scalingStyle).scaledValue(for: base, compatibleWith: traits)
        // Very large accessibility sizes still leave room for a few words a line.
        let pointSize = min(scaled, base * 2)
        let weight = boldText ? self.weight.heavier : self.weight
        if extraClearLetters {
            return .custom(weight.hyperlegibleName, fixedSize: pointSize)
        }
        return .system(size: pointSize, weight: weight.systemWeight)
    }
}

enum AppFontWeight {
    case regular
    case medium
    case semibold
    case bold
    case heavy

    var systemWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }

    /// The matching Atkinson Hyperlegible Next face (see FontRegistrar).
    var hyperlegibleName: String {
        switch self {
        case .regular: "AtkinsonHyperlegibleNext-Regular"
        case .medium, .semibold: "AtkinsonHyperlegibleNext-Bold"
        case .bold, .heavy: "AtkinsonHyperlegibleNext-ExtraBold"
        }
    }

    /// Used when the iPhone's Bold Text setting is on.
    var heavier: AppFontWeight {
        switch self {
        case .regular: .semibold
        case .medium, .semibold: .bold
        case .bold, .heavy: .heavy
        }
    }
}

extension DynamicTypeSize {
    /// The UIKit name for the same text size.
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

/// The family's text size choice, applied on top of Dynamic Type.
/// Reading ability can change through the day, so the family can raise it.
enum TextSize: String, CaseIterable, Identifiable {
    case standard
    case large
    case larger

    var id: String { rawValue }

    var scale: CGFloat {
        switch self {
        case .standard: 1.0
        case .large: 1.12
        case .larger: 1.25
        }
    }

    var label: String {
        switch self {
        case .standard: "Standard"
        case .large: "Large"
        case .larger: "Larger"
        }
    }
}

extension EnvironmentValues {
    /// Extra text scale chosen by the family (see `TextSize`).
    @Entry var textScale: CGFloat = 1
    /// "Extra-clear letters": Atkinson Hyperlegible instead of the system font.
    @Entry var usesExtraClearLetters: Bool = false
}

private struct AppFontModifier: ViewModifier {
    let style: AppTextStyle
    @Environment(\.textScale) private var textScale
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesExtraClearLetters) private var usesExtraClearLetters

    func body(content: Content) -> some View {
        content.font(style.font(
            scale: textScale,
            dynamicTypeSize: dynamicTypeSize,
            boldText: legibilityWeight == .bold,
            extraClearLetters: usesExtraClearLetters
        ))
    }
}

extension View {
    /// Applies one of the app's text styles.
    func appFont(_ style: AppTextStyle) -> some View {
        modifier(AppFontModifier(style: style))
    }
}
