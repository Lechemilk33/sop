import CoreText
import Foundation

/// Registers the bundled Atkinson Hyperlegible Next fonts (SIL Open Font
/// License, see Resources/Fonts/OFL.txt). If registration ever fails, SwiftUI
/// falls back to the system font, which still scales with Dynamic Type.
enum FontRegistrar {
    static let fontFileNames = [
        "AtkinsonHyperlegibleNext-Regular",
        "AtkinsonHyperlegibleNext-Bold",
        "AtkinsonHyperlegibleNext-ExtraBold",
    ]

    static func registerBundledFonts() {
        for name in fontFileNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            // Registering twice (for example in previews) reports an error we can ignore.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
