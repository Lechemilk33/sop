import SwiftUI

/// The layout every one of his screens shares: the top bar pinned at the top
/// (Home in the top-right corner), the content in the middle, and the main
/// actions pinned at the bottom so they are always in the same place.
///
/// The content only becomes scrollable when it truly doesn't fit (for example
/// with very large text). When it fits, there is nothing to swipe at all.
struct ScreenScaffold<Content: View, Footer: View>: View {
    private let showsTopBar: Bool
    private let content: Content
    private let footer: Footer

    init(
        showsTopBar: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.showsTopBar = showsTopBar
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTopBar {
                ScreenTopBar()
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            ViewThatFits(in: .vertical) {
                contentStack
                    .frame(maxHeight: .infinity, alignment: .top)
                ScrollView {
                    contentStack
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if !(footer is EmptyView) {
                footer
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
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
    init(showsTopBar: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(showsTopBar: showsTopBar, content: content, footer: { EmptyView() })
    }
}
