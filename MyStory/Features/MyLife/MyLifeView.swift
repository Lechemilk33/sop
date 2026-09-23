import SwiftData
import SwiftUI

/// His life, by chapter. "Play me a story" needs no choices at all.
struct MyLifeView: View {
    @Environment(Router.self) private var router
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    var body: some View {
        let filled = chapters.filter { $0.storyCount > 0 }
        ScreenScaffold {
            SectionHeader(title: "My life", systemImage: Symbols.life, tone: .marigold)
            if filled.isEmpty {
                EmptyStateMessage(
                    title: "Your stories will live here",
                    message: "Each story you tell is saved in a chapter of your life."
                )
                BigButton("Tell a story", systemImage: Symbols.tell, tone: .brick, size: .large) {
                    router.replaceTop(with: .tellStory(.next))
                }
            } else {
                BigButton("Play me a story", systemImage: Symbols.play, tone: .marigold, size: .large) {
                    router.push(.player(.surprise))
                }
                Text("Or pick a chapter:")
                    .appFont(.bodyBold)
                    .foregroundStyle(Palette.softInk)
                VStack(spacing: Metrics.itemSpacing) {
                    ForEach(filled) { chapter in
                        ChapterRow(chapter: chapter) {
                            router.push(.chapter(chapter))
                        }
                    }
                }
            }
        }
    }
}
