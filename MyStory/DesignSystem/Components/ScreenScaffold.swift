import SwiftUI

/// Where a screen's back button goes, when it isn't simply the previous
/// screen (for example, from naming a story back to "Tell a story").
struct BackAction {
    let title: String
    let action: () -> Void
}

/// The layout every one of his screens shares: the top bar pinned at the top
/// (Home in the top-right corner), the content in the middle, and the main
/// actions pinned at the bottom so they are always in the same place.
///
/// The content only scrolls when it truly doesn't fit (for example with very
/// large text or the keyboard up). When it fits, it doesn't move or bounce,
/// so there is nothing to swipe. It's always the same scroll view, so a box
/// he's typing in never loses the keyboard when space changes.
struct ScreenScaffold<Content: View, Footer: View>: View {
    private let showsTopBar: Bool
    private let back: BackAction?
    private let content: Content
    private let footer: Footer

    @Environment(\.placeTone) private var placeTone

    init(
        showsTopBar: Bool = true,
        back: BackAction? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.showsTopBar = showsTopBar
        self.back = back
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTopBar {
                ScreenTopBar(back: back)
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            ScrollView {
                contentStack
            }
            .scrollBounceBehavior(.basedOnSize)
            // Only the keyboard's own key hides it; no hidden gestures.
            .scrollDismissesKeyboard(.never)
            .frame(maxHeight: .infinity)
            if !(footer is EmptyView) {
                footer
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .background(Backdrop(tone: placeTone))
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, showsTopBar ? 4 : 24)
        .padding(.bottom, 24)
    }
}

extension ScreenScaffold where Footer == EmptyView {
    init(showsTopBar: Bool = true, back: BackAction? = nil, @ViewBuilder content: () -> Content) {
        self.init(showsTopBar: showsTopBar, back: back, content: content, footer: { EmptyView() })
    }
}
