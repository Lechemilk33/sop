import SwiftUI

/// The layout every one of his screens shares: the top bar pinned at the top,
/// the content in the middle (it only scrolls when it doesn't fit, for example
/// with very large text), and the main actions pinned at the bottom so they
/// are always in the same place.
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
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, showsTopBar ? 4 : 24)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            if !(footer is EmptyView) {
                footer
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
    }
}

extension ScreenScaffold where Footer == EmptyView {
    init(showsTopBar: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(showsTopBar: showsTopBar, content: content, footer: { EmptyView() })
    }
}
