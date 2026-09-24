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

/// Giving a story a name: anything he likes.
struct RenameStoryView: View {
    let story: Story

    @Environment(Router.self) private var router

    @State private var name = ""
    @State private var hasLoaded = false
    @FocusState private var isTyping: Bool

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Name this story", systemImage: Symbols.rename, tone: .marigold)
            Text("What would you like to call it?")
                .appFont(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            TextEntryField(
                placeholder: "For example: The summer at the lake",
                text: $name,
                isFocused: $isTyping
            )
            Text("To say it instead of typing, tap the microphone on the keyboard.")
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        } footer: {
            BigButton("Save the name", systemImage: Symbols.done, tone: .marigold, size: .large) {
                save()
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            name = story.title
        }
    }

    private func save() {
        isTyping = false
        let cleaned = StoryTitles.cleaned(name)
        if !cleaned.isEmpty {
            story.title = cleaned
        } else if story.promptText.isEmpty {
            story.title = StoryTitles.untitled(on: story.recordedAt)
        } else {
            // Named by its question again.
            story.title = ""
        }
        try? story.modelContext?.save()
        router.pop()
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
            SectionHeader(title: "Who's in this story?", systemImage: Symbols.people, tone: .blue)
            if people.isEmpty {
                EmptyStateMessage(
                    title: "No one here yet",
                    message: "Your family will add the people in your life, with their photos. Then you can choose them here."
                )
            } else {
                Instruction("Tap everyone who's part of it. Tap again to take someone off.")
                PeopleGrid(people: people, selected: Set((story.people ?? []).map(\.persistentModelID))) { person in
                    toggle(person)
                }
            }
        } footer: {
            BigButton("Done", systemImage: Symbols.done, tone: .blue, size: .regular) {
                router.pop()
            }
        }
    }

    private func toggle(_ person: Person) {
        var chosen = story.people ?? []
        if let index = chosen.firstIndex(where: { $0.persistentModelID == person.persistentModelID }) {
            chosen.remove(at: index)
        } else {
            chosen.append(person)
        }
        story.people = chosen
        try? story.modelContext?.save()
    }
}

/// Moving a story to another chapter, or into a new one.
struct StoryChapterView: View {
    let story: Story

    @Environment(Router.self) private var router
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Which chapter?", systemImage: Symbols.chapter, tone: .marigold)
            Instruction("Tap the chapter this story belongs in.")
            BigButton("Make a new chapter", systemImage: Symbols.newChapter, tone: .outline, size: .compact) {
                router.push(.newChapter(for: story))
            }
            VStack(spacing: Metrics.itemSpacing) {
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
