import SwiftData
import SwiftUI

/// Making a new chapter, or changing the name and picture of a chapter he
/// made. A new chapter made while sorting a story takes that story straight
/// away, and he goes back to "About this story".
struct ChapterEditorView: View {
    let chapter: Chapter?
    let storyToFile: Story?

    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var symbol = Symbols.simpleChapterChoices[0].symbol
    @State private var hasLoaded = false
    @State private var note: String?
    @FocusState private var isTyping: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3)

    var body: some View {
        ScreenScaffold {
            SectionHeader(
                title: chapter == nil ? "A new chapter" : "Change this chapter",
                systemImage: symbol,
                tone: .marigold
            )
            Text("What would you like to call it?")
                .appFont(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let note {
                Instruction(note)
            }
            TextEntryField(example: "For example: Fishing trips", text: $name, isFocused: $isTyping)
            Text("Choose a picture for it")
                .appFont(.subtitle)
                .foregroundStyle(Palette.ink)
                .padding(.top, 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(choices, id: \.symbol) { choice in
                    PictureChoice(symbol: choice.symbol, name: choice.name, isSelected: choice.symbol == symbol) {
                        isTyping = false
                        symbol = choice.symbol
                    }
                }
            }
        } footer: {
            BigButton(
                chapter == nil ? "Make the chapter" : "Save the chapter",
                systemImage: Symbols.done,
                tone: .marigold,
                size: .large
            ) {
                save()
            }
        }
        .onAppear(perform: load)
    }

    /// The pictures to choose from, including the chapter's own if it has a
    /// different one.
    private var choices: [(symbol: String, name: String)] {
        let simple = Symbols.simpleChapterChoices
        guard let current = chapter?.symbolName, !simple.contains(where: { $0.symbol == current }) else { return simple }
        let name = Symbols.chapterChoices.first { $0.symbol == current }?.name ?? "As it was"
        return [(symbol: current, name: name)] + simple
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if let chapter {
            name = chapter.name
            symbol = chapter.symbolName
        }
    }

    private func save() {
        let cleaned = StoryTitles.cleaned(name)
        guard !cleaned.isEmpty else {
            // Nothing is greyed out: the button shows him what's missing.
            note = "Type a name for the chapter first."
            isTyping = true
            return
        }
        isTyping = false
        if let chapter {
            chapter.name = cleaned
            chapter.symbolName = symbol
            try? context.save()
            router.pop()
            return
        }
        let newChapter = Chapter(key: "", name: cleaned, symbolName: symbol, sortOrder: 0, askPriority: 50)
        ChapterOrdering.add(newChapter, in: context)
        if let story = context.existing(storyToFile) {
            story.chapter = newChapter
            try? context.save()
            // Past "Choose a chapter", back to "About this story".
            router.pop(2)
        } else {
            try? context.save()
            router.pop()
        }
    }
}

/// A picture for a chapter, with its word underneath.
private struct PictureChoice: View {
    let symbol: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .accessibilityHidden(true)
                Text(name)
                    .appFont(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(shape.fill(isSelected ? Palette.marigold : Palette.card))
            .overlay(
                shape.strokeBorder(
                    isSelected ? Palette.marigoldRim : Palette.edge,
                    lineWidth: isSelected ? Metrics.increasedContrastBorder : Metrics.tappableBorder
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
