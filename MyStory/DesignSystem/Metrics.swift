import CoreGraphics

/// Sizes and spacing. Touch studies with older adults found targets of about
/// 16.5–19 mm work best (roughly 100–115 pt), far above Apple's 44 pt minimum.
enum Metrics {
    static let screenPadding: CGFloat = 20
    /// Space between the main buttons on a screen.
    static let sectionSpacing: CGFloat = 20
    static let itemSpacing: CGFloat = 14

    static let heroButtonHeight: CGFloat = 136
    static let largeButtonHeight: CGFloat = 104
    static let buttonHeight: CGFloat = 84
    static let compactButtonHeight: CGFloat = 68
    /// Nothing tappable is ever smaller than this.
    static let minimumTarget: CGFloat = 64
    static let navButtonHeight: CGFloat = 60

    static let cornerRadius: CGFloat = 24
    static let heroCornerRadius: CGFloat = 28
    static let cardCornerRadius: CGFloat = 22

    static let tappableBorder: CGFloat = 3
    static let staticBorder: CGFloat = 2
}
