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
///
/// At the largest accessibility text sizes the main actions would leave no
/// room for anything else, so they scroll with the content instead.
/// Coming back to a list shows the item he last opened, not the top.
struct ScreenScaffold<Content: View, Footer: View>: View {
    private let showsTopBar: Bool
    private let back: BackAction?
    private let content: Content
    private let footer: Footer

    @Environment(\.placeTone) private var placeTone
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(Router.self) private var router

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

    private var hasFooter: Bool {
        !(footer is EmptyView)
    }

    private var footerScrolls: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTopBar {
                ScreenTopBar(back: back)
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        contentStack
                        if hasFooter, footerScrolls {
                            footer
                                .padding(.horizontal, Metrics.screenPadding)
                                .padding(.bottom, 24)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                // Only the keyboard's own key hides it; no hidden gestures.
                .scrollDismissesKeyboard(.never)
                .task {
                    if let anchor = router.anchor(for: router.currentID) {
                        proxy.scrollTo(anchor, anchor: .center)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            if hasFooter, !footerScrolls {
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
