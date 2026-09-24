import SwiftData
import SwiftUI

/// His stories, kept in chapters of his life. "Play me a story" needs no
/// choices at all; everything else is a tap away. Chapters he or the family
/// made show up here even before they have stories.
struct MyStoriesView: View {
    @Environment(Router.self) private var router
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]
    @Query private var stories: [Story]

    var body: some View {
        let shown = chapters.filter { $0.storyCount > 0 || $0.key.isEmpty }
        ScreenScaffold {
            SectionHeader(title: "My stories", systemImage: Symbols.stories, tone: .marigold)
            if stories.isEmpty {
                EmptyStateMessage(
                    title: "Your stories will live here",
                    message: "Each story you tell is saved here, in a chapter of your life."
                )
                BigButton("Tell a story", systemImage: Symbols.tell, tone: .brick, size: .large) {
                    router.replaceTop(with: .tellStory(.start))
                }
            } else {
                BigButton("Play me a story", systemImage: Symbols.play, tone: .marigold, size: .large) {
                    router.push(.player(.surprise))
                }
                TappableRow(
                    title: "All my stories",
                    detail: StoryCountText.text(stories.count),
                    accessibilityText: "All my stories. \(StoryCountText.text(stories.count)).",
                    action: { router.push(.allStories) }
                ) {
                    Medallion(systemImage: Symbols.allStories, tone: .marigold, size: Metrics.smallMedallion)
                } trailing: {
                    RowChevron()
                }
            }
            if !shown.isEmpty {
                Text("Chapters")
                    .appFont(.subtitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)
                VStack(spacing: Metrics.itemSpacing) {
                    ForEach(shown) { chapter in
                        ChapterRow(chapter: chapter) {
                            router.push(.chapter(chapter))
                        }
                    }
                }
            }
            BigButton("Make a new chapter", systemImage: Symbols.newChapter, tone: .outline, size: .regular) {
                router.push(.newChapter(for: nil))
            }
        }
    }
}

/// Every story, newest first.
struct AllStoriesView: View {
    @Environment(Router.self) private var router
    @Query(sort: \Story.recordedAt, order: .reverse) private var stories: [Story]

    var body: some View {
        StoryListScreen(
            title: "All my stories",
            systemImage: Symbols.allStories,
            tone: .marigold,
            stories: stories,
            emptyMessage: "Tell a story, and it will be here."
        ) {
            BigButton("Tell a story", systemImage: Symbols.tell, tone: .brick, size: .regular) {
                router.push(.tellStory(.start))
            }
        }
    }
}
