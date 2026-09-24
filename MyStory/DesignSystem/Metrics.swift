import CoreGraphics

/// Sizes and spacing. Touch studies with older adults found targets of about
/// 16.5–19 mm work best (roughly 100–115 pt), far above Apple's 44 pt minimum.
enum Metrics {
    static let screenPadding: CGFloat = 20
    /// Space between the main buttons on a screen.
    static let sectionSpacing: CGFloat = 20
    /// Space between rows and secondary buttons. Touch studies with older
    /// adults suggest generous gaps, so this matches the main spacing.
    static let itemSpacing: CGFloat = 20

    static let heroButtonHeight: CGFloat = 136
    static let largeButtonHeight: CGFloat = 104
    static let buttonHeight: CGFloat = 88
    static let compactButtonHeight: CGFloat = 72
    /// Nothing tappable is ever smaller than this.
    static let minimumTarget: CGFloat = 64
    static let navButtonHeight: CGFloat = 64

    /// Rounded corners follow iOS 26: generous and concentric.
    static let cornerRadius: CGFloat = 28
    static let heroCornerRadius: CGFloat = 34
    static let cardCornerRadius: CGFloat = 26
    static let rowCornerRadius: CGFloat = 24

    /// Edge of anything tappable. Thin but at least 3:1, and thicker with
    /// Increase Contrast.
    static let tappableBorder: CGFloat = 2
    static let increasedContrastBorder: CGFloat = 3
    static let staticBorder: CGFloat = 1

    /// Medallions: the colored circles that carry an icon.
    static let medallion: CGFloat = 60
    static let smallMedallion: CGFloat = 52
    static let tileMedallion: CGFloat = 76
    /// The solid stripe of the place's color down the side of Home's tiles.
    static let tileStripe: CGFloat = 14
}
