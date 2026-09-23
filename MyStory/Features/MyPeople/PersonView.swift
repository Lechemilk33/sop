import SwiftUI

/// One person: a big photo, their name, what they are to him, a few things to
/// remember, their recorded hello, and the stories they're in.
struct PersonView: View {
    let person: Person

    @Environment(Router.self) private var router
    @Environment(ClipPlayer.self) private var clipPlayer

    var body: some View {
        let helloID = "hello-\(person.uuid.uuidString)"
        let isPlayingHello = clipPlayer.isPlaying(helloID)
        ScreenScaffold {
            StoredImage(cacheKey: person.photoCacheKey, data: person.photoData ?? person.thumbnailData)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

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

            if person.helloAudio != nil {
                BigButton(
                    isPlayingHello ? "Playing \(person.name)'s message…" : "Hear \(person.name)",
                    systemImage: isPlayingHello ? Symbols.pause : Symbols.hello,
                    tone: .marigold,
                    size: .regular
                ) {
                    clipPlayer.toggle(id: helloID, data: person.helloAudio)
                }
            }

            if person.storyCount > 0 {
                BigButton(
                    "Stories with \(person.name) (\(person.storyCount))",
                    systemImage: Symbols.life,
                    tone: .outline,
                    size: .regular
                ) {
                    router.push(.personStories(person))
                }
            }

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
            stories: stories,
            emptyMessage: "No stories with \(person.name) yet."
        ) {
            BigButton("Tell a story about \(person.name)", systemImage: Symbols.tell, tone: .brick, size: .regular) {
                router.push(.tellStory(.about(person)))
            }
        }
    }
}
