import SwiftUI

/// One person: their photo framed around their face, their name, what they
/// are to him, their recorded hello and the stories they're in, then a few
/// things to remember. What he can do comes first, so it's on the screen
/// without scrolling.
struct PersonView: View {
    let person: Person

    @Environment(Router.self) private var router
    @Environment(ClipPlayer.self) private var clipPlayer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.textScale) private var textScale

    var body: some View {
        let helloID = "hello-\(person.uuid.uuidString)"
        let isPlayingHello = clipPlayer.isPlaying(helloID)
        // With very large text the name goes under the photo, so it has room.
        let heading = dynamicTypeSize.isAccessibilitySize || textScale > 1.2
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
        ScreenScaffold {
            heading {
                StoredImage(
                    cacheKey: person.thumbnailCacheKey,
                    data: person.thumbnailData ?? person.photoData,
                    maxPixelSize: ImageCache.largePixels
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 164, height: 164)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.hairline, lineWidth: Metrics.staticBorder))
                .shadow(color: Palette.ink.opacity(0.08), radius: 16, y: 6)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .appFont(.personName)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if !person.relationship.isEmpty {
                        Text(person.relationship)
                            .appFont(.subtitle)
                            .foregroundStyle(Palette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if person.helloAudio != nil {
                BigButton(
                    isPlayingHello ? "Stop \(person.name)\u{2019}s message" : "Hear \(person.name)",
                    systemImage: isPlayingHello ? Symbols.stop : Symbols.hello,
                    tone: .marigold,
                    size: .regular
                ) {
                    clipPlayer.toggle(id: helloID, data: person.helloAudio)
                }
            }

            if person.storyCount > 0 {
                BigButton(
                    "Stories with \(person.name) (\(person.storyCount))",
                    systemImage: Symbols.stories,
                    tone: .outline,
                    size: .regular
                ) {
                    router.push(.personStories(person))
                }
            }

            let facts = person.visibleFacts
            if !facts.isEmpty {
                InfoCard(spacing: 8) {
                    ForEach(facts, id: \.self) { fact in
                        Text(fact)
                            .appFont(.body)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } footer: {
            BigButton("Tell a story about \(person.name)", systemImage: Symbols.tell, tone: .brick, size: .regular) {
                router.push(.tellStory(.about(person)))
            }
        }
        .onDisappear { clipPlayer.stop() }
    }
}

/// Every story someone is in.
struct PersonStoriesView: View {
    let person: Person

    @Environment(Router.self) private var router

    var body: some View {
        let stories = (person.stories ?? []).sorted { $0.recordedAt > $1.recordedAt }
        StoryListScreen(
            title: "Stories with \(person.name)",
            systemImage: Symbols.people,
            tone: .blue,
            stories: stories,
            emptyMessage: "No stories with \(person.name) yet. You can add \(person.name) to a story from its About this story page."
        ) {
            BigButton("Tell a story about \(person.name)", systemImage: Symbols.tell, tone: .brick, size: .regular) {
                router.push(.tellStory(.about(person)))
            }
        }
    }
}
