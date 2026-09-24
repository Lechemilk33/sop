import SwiftData
import SwiftUI

/// "About this story": its name, who's in it, its chapter and its photo,
/// each a tap away from changing. Nothing here can delete a story.
struct StoryDetailsView: View {
    let story: Story

    @Environment(Router.self) private var router

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "About this story", systemImage: Symbols.organize, tone: .marigold)
            Instruction("Tap anything to change it.")
            VStack(spacing: Metrics.itemSpacing) {
                TappableRow(
                    eyebrow: "Name",
                    title: story.displayTitle,
                    detail: nil,
                    accessibilityText: "Name: \(story.displayTitle). Tap to change it.",
                    action: { router.push(.renameStory(story)) }
                ) {
                    Medallion(systemImage: Symbols.rename, tone: .marigold, size: Metrics.smallMedallion)
                } trailing: {
                    RowChevron()
                }

                TappableRow(
                    eyebrow: "Who's in it",
                    title: peopleText,
                    detail: nil,
                    accessibilityText: "Who's in it: \(peopleText). Tap to change it.",
                    action: { router.push(.storyPeople(story)) }
                ) {
                    Medallion(systemImage: Symbols.people, tone: .blue, size: Metrics.smallMedallion)
                } trailing: {
                    RowChevron()
                }

                TappableRow(
                    eyebrow: "Chapter",
                    title: chapterText,
                    detail: nil,
                    accessibilityText: "Chapter: \(chapterText). Tap to change it.",
                    action: { router.push(.storyChapter(story)) }
                ) {
                    Medallion(systemImage: story.chapter?.symbolName ?? Symbols.chapter, tone: .marigold, size: Metrics.smallMedallion)
                } trailing: {
                    RowChevron()
                }

                TappableRow(
                    eyebrow: "Photo",
                    title: story.photo == nil ? "No photo yet" : "A photo is added",
                    detail: nil,
                    accessibilityText: story.photo == nil ? "Photo: none yet. Tap to add one." : "Photo: added. Tap to change it.",
                    action: { router.push(.storyPhoto(story)) }
                ) {
                    if let photo = story.photo {
                        StoredImage(cacheKey: photo.thumbnailCacheKey, data: photo.thumbnailData ?? photo.imageData, placeholderSymbol: Symbols.photo)
                            .frame(width: Metrics.smallMedallion, height: Metrics.smallMedallion)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Medallion(systemImage: Symbols.photo, tone: .marigold, size: Metrics.smallMedallion)
                    }
                } trailing: {
                    RowChevron()
                }
            }
        } footer: {
            BigButton("Done", systemImage: Symbols.done, tone: .marigold, size: .regular) {
                router.pop()
            }
        }
    }

    private var peopleText: String {
        let names = story.sortedPeople.map(\.name)
        return names.isEmpty ? "No one yet" : ListText.joined(names)
    }

    private var chapterText: String {
        story.chapter?.name ?? "More stories"
    }
}

/// Giving a story a name: anything he likes. The box starts empty, with
/// the current name above it; an empty box keeps that name. Going back
/// keeps what he typed too.
struct RenameStoryView: View {
    let story: Story

    @Environment(Router.self) private var router

    @State private var name = ""
    @FocusState private var isTyping: Bool

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Name this story", systemImage: Symbols.rename, tone: .marigold)
            CurrentName(story: story)
            Text("What would you like to call it?")
                .appFont(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            TextEntryField(
                example: "For example: The summer at the lake. Leave it empty to keep the name it has.",
                text: $name,
                isFocused: $isTyping
            )
            TypingTip()
        } footer: {
            BigButton(
                StoryTitles.cleaned(name).isEmpty ? "Keep this name" : "Save the name",
                systemImage: Symbols.done,
                tone: .marigold,
                size: .large
            ) {
                isTyping = false
                router.pop()
            }
        }
        .onDisappear {
            StoryEditing.rename(story, to: name)
        }
    }
}

/// Choosing who's in a story. Each tap adds or takes away one person, and
/// is saved straight away.
struct StoryPeopleView: View {
    let story: Story

    @Environment(Router.self) private var router
    @Query(sort: \Person.sortOrder) private var people: [Person]

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Choose the people in it", systemImage: Symbols.people, tone: .marigold)
            CurrentName(story: story)
            if people.isEmpty {
                EmptyStateMessage(
                    title: "No one here yet",
                    message: "Your family will add the people in your life, with their photos. Then you can choose them here."
                )
            } else {
                Instruction("Tap everyone who's part of this story. Tap again to take someone off.")
                PeopleGrid(people: people, selected: Set((story.people ?? []).map(\.persistentModelID))) { person in
                    StoryEditing.togglePerson(person, in: story)
                }
            }
        } footer: {
            BigButton("Done", systemImage: Symbols.done, tone: .marigold, size: .regular) {
                router.pop()
            }
        }
    }
}

/// Moving a story to another chapter, or into a new one.
struct StoryChapterView: View {
    let story: Story

    @Environment(Router.self) private var router
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Choose a chapter for it", systemImage: Symbols.chapter, tone: .marigold)
            CurrentName(story: story)
            BigButton("Make a new chapter", systemImage: Symbols.newChapter, tone: .outline, size: .compact) {
                router.push(.newChapter(for: story))
            }
            LazyVStack(spacing: Metrics.itemSpacing) {
                ForEach(chapters) { chapter in
                    ChapterRow(chapter: chapter, isSelected: story.chapter?.persistentModelID == chapter.persistentModelID) {
                        story.chapter = chapter
                        try? story.modelContext?.save()
                    }
                }
            }
        } footer: {
            BigButton("Done", systemImage: Symbols.done, tone: .marigold, size: .regular) {
                router.pop()
            }
        }
    }
}
