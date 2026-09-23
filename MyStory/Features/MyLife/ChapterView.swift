import SwiftUI

/// One chapter: "Play them all", then each story.
struct ChapterView: View {
    let chapter: Chapter

    @Environment(Router.self) private var router

    var body: some View {
        let stories = chapter.sortedStories
        StoryListScreen(
            title: chapter.name,
            systemImage: chapter.symbolName,
            stories: stories,
            emptyMessage: "No stories in this chapter yet."
        ) {
            BigButton("Tell a story for this chapter", systemImage: Symbols.tell, tone: .brick, size: .regular) {
                router.push(.tellStory(.chapter(chapter)))
            }
        }
    }
}

/// The list layout shared by a chapter and by someone's stories.
struct StoryListScreen<Extra: View>: View {
    let title: String
    let systemImage: String
    let stories: [Story]
    let emptyMessage: String
    let extra: Extra

    @Environment(Router.self) private var router

    init(
        title: String,
        systemImage: String,
        stories: [Story],
        emptyMessage: String,
        @ViewBuilder extra: () -> Extra
    ) {
        self.title = title
        self.systemImage = systemImage
        self.stories = stories
        self.emptyMessage = emptyMessage
        self.extra = extra()
    }

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: title, systemImage: systemImage, tone: .marigold)
            if stories.isEmpty {
                EmptyStateMessage(title: "Nothing here yet", message: emptyMessage)
            } else {
                BigButton(
                    stories.count == 1 ? "Play it" : "Play them all",
                    systemImage: Symbols.play,
                    tone: .marigold,
                    size: .regular
                ) {
                    router.push(.player(.queue(stories, startIndex: 0)))
                }
                VStack(spacing: Metrics.itemSpacing) {
                    ForEach(stories) { story in
                        StoryRow(story: story) {
                            router.push(.player(.single(story)))
                        }
                    }
                }
            }
            extra
        }
    }
}
