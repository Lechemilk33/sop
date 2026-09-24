import SwiftData
import SwiftUI

/// Making a new chapter, or changing a chapter's name and picture. A new
/// chapter made while sorting a story takes that story straight away.
struct ChapterEditorView: View {
    let chapter: Chapter?
    let storyToFile: Story?

    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var symbol = Symbols.chapterChoices[0].symbol
    @State private var hasLoaded = false
    @FocusState private var isTyping: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3)

    var body: some View {
        let cleaned = StoryTitles.cleaned(name)
        ScreenScaffold {
            SectionHeader(
                title: chapter == nil ? "A new chapter" : "Change this chapter",
                systemImage: symbol,
                tone: .marigold
            )
            Text("What's it called?")
                .appFont(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            TextEntryField(placeholder: "For example: Fishing trips", text: $name, isFocused: $isTyping)
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
                cleaned.isEmpty ? "Type a name first" : (chapter == nil ? "Make the chapter" : "Save the chapter"),
                systemImage: Symbols.done,
                tone: .marigold,
                size: .large
            ) {
                save()
            }
            .disabled(cleaned.isEmpty)
        }
        .onAppear(perform: load)
    }

    /// The pictures to choose from, including the chapter's own if it has a
    /// different one.
    private var choices: [(symbol: String, name: String)] {
        let all = Symbols.chapterChoices
        guard let current = chapter?.symbolName, !all.contains(where: { $0.symbol == current }) else { return all }
        return [(symbol: current, name: "As it was")] + all
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
        guard !cleaned.isEmpty else { return }
        isTyping = false
        if let chapter {
            chapter.name = cleaned
            chapter.symbolName = symbol
        } else {
            let existing = (try? context.fetch(FetchDescriptor<Chapter>())) ?? []
            let nextOrder = (existing.map(\.sortOrder).max() ?? 0) + 1
            let newChapter = Chapter(key: "", name: cleaned, symbolName: symbol, sortOrder: nextOrder, askPriority: 50)
            context.insert(newChapter)
            storyToFile?.chapter = newChapter
        }
        try? context.save()
        router.pop()
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 92)
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
