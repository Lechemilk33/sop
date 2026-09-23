import SwiftUI

/// The app's text styles. Sizes follow PLAN.md: nothing below 20 pt, reading
/// text at 22 pt, questions at 30 pt. Every style scales with the iPhone's
/// text size setting (Dynamic Type) and with the family's text size choice.
enum AppTextStyle {
    case greeting
    case screenTitle
    case personName
    case question
    case heroButton
    case largeButton
    case button
    case compactButton
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
        case .heroButton: 32
        case .largeButton: 30
        case .button: 26
        case .compactButton: 22
        case .subtitle: 24
        case .body: 22
        case .bodyBold: 22
        case .caption: 20
        }
    }

    fileprivate var weight: AppFontWeight {
        switch self {
        case .body: .regular
        case .subtitle, .bodyBold, .caption: .bold
        default: .extraBold
        }
    }

    fileprivate var relativeTo: Font.TextStyle {
        switch self {
        case .greeting, .screenTitle, .personName: .largeTitle
        case .question, .heroButton, .largeButton: .title
        case .button: .title2
        case .compactButton, .subtitle: .title3
        case .body, .bodyBold: .body
        case .caption: .callout
        }
    }

    func font(scale: CGFloat, boldText: Bool) -> Font {
        let weight = boldText ? self.weight.heavier : self.weight
        return Font.custom(weight.postScriptName, size: size * scale, relativeTo: relativeTo)
    }
}

enum AppFontWeight {
    case regular
    case bold
    case extraBold

    var postScriptName: String {
        switch self {
        case .regular: "AtkinsonHyperlegibleNext-Regular"
        case .bold: "AtkinsonHyperlegibleNext-Bold"
        case .extraBold: "AtkinsonHyperlegibleNext-ExtraBold"
        }
    }

    /// Used when the iPhone's Bold Text setting is on.
    var heavier: AppFontWeight {
        switch self {
        case .regular: .bold
        case .bold, .extraBold: .extraBold
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
}

private struct AppFontModifier: ViewModifier {
    let style: AppTextStyle
    @Environment(\.textScale) private var textScale
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        content.font(style.font(scale: textScale, boldText: legibilityWeight == .bold))
    }
}

extension View {
    /// Applies one of the app's text styles.
    func appFont(_ style: AppTextStyle) -> some View {
        modifier(AppFontModifier(style: style))
    }
}
