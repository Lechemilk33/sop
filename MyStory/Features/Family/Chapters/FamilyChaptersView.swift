import SwiftData
import SwiftUI

/// Every chapter of his stories, in the order he sees them. Chapters can be
/// added, reordered, renamed or given another picture; chapters that he or
/// the family made can also be deleted, and their stories move to More
/// stories.
struct FamilyChaptersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    FamilyChapterEditorView(chapter: nil)
                } label: {
                    FamilyMenuRow(title: "New chapter", systemImage: "folder.badge.plus")
                }
            }
            Section {
                ForEach(chapters) { chapter in
                    NavigationLink {
                        FamilyChapterEditorView(chapter: chapter)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: chapter.symbolName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Palette.marigoldRim)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Palette.marigoldTint))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.name)
                                    .font(.body.weight(.semibold))
                                Text(StoryCountText.text(chapter.storyCount))
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.softInk)
                            }
                        }
                    }
                    // More stories stays last: it catches everything else.
                    .moveDisabled(chapter.key == QuestionBank.moreStoriesKey)
                }
                .onMove(perform: move)
            } header: {
                Text("In My stories")
            } footer: {
                Text("Tap Edit to change the order. He can also make chapters and move stories himself, from any story's About this story page.")
            }
        }
        .familyBackground()
        .navigationTitle("Chapters")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = chapters
        ordered.move(fromOffsets: source, toOffset: destination)
        // Nothing can be moved below More stories.
        if let last = ordered.firstIndex(where: { $0.key == QuestionBank.moreStoriesKey }) {
            ordered.append(ordered.remove(at: last))
        }
        for (index, chapter) in ordered.enumerated() {
            chapter.sortOrder = index
        }
        try? context.save()
    }
}

/// Make a chapter, or rename one or change its picture. More stories and My
/// thoughts keep their names, because the app files stories there by
/// itself. Chapters that aren't built in can be deleted; their stories are
/// never deleted with them.
struct FamilyChapterEditorView: View {
    let chapter: Chapter?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var symbol = Symbols.chapterChoices[0].symbol
    @State private var hasLoaded = false
    @State private var isConfirmingDelete = false
    /// Deleted only once the editor has closed, so nothing on screen is
    /// still showing the chapter when it's removed.
    @State private var deleteWhenGone = false

    private var cleanedName: String {
        ChapterOrdering.cleanedName(name)
    }

    private var canRename: Bool {
        chapter.map(ChapterOrdering.isRenamable) ?? true
    }

    var body: some View {
        Form {
            Section {
                TextField("Chapter name", text: $name)
                    .font(.title3)
                    .disabled(!canRename)
            } header: {
                Text("Name")
            } footer: {
                if !canRename {
                    Text("This chapter keeps its name, because the app files stories here by itself.")
                }
            }
            Section("Picture") {
                Picker("Picture", selection: $symbol) {
                    ForEach(choices, id: \.symbol) { choice in
                        Label(choice.name, systemImage: choice.symbol)
                            .tag(choice.symbol)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            if let chapter, chapter.key.isEmpty {
                Section {
                    Button("Delete this chapter", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } footer: {
                    Text(chapter.storyCount > 0 ? "Its stories are kept. They move to More stories." : "It has no stories yet.")
                }
            }
        }
        .familyBackground()
        .navigationTitle(chapter == nil ? "New chapter" : "Chapter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(cleanedName.isEmpty)
            }
        }
        .onAppear(perform: load)
        .onDisappear {
            if deleteWhenGone { deleteChapter() }
        }
        .confirmationDialog("Delete this chapter?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete chapter", role: .destructive, action: delete)
        } message: {
            Text("No stories are deleted.")
        }
    }

    /// The pictures to choose from, including the chapter's own.
    private var choices: [(symbol: String, name: String)] {
        let all = Symbols.chapterChoices
        guard let current = chapter?.symbolName, !all.contains(where: { $0.symbol == current }) else { return all }
        return [(symbol: current, name: "As it was")] + all
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let chapter else { return }
        name = chapter.name
        symbol = chapter.symbolName
    }

    private func save() {
        guard !cleanedName.isEmpty else { return }
        if let chapter {
            if canRename {
                chapter.name = cleanedName
            }
            chapter.symbolName = symbol
        } else {
            ChapterOrdering.add(
                Chapter(key: "", name: cleanedName, symbolName: symbol, sortOrder: 0, askPriority: 50),
                in: context
            )
        }
        try? context.save()
        dismiss()
    }

    private func delete() {
        guard chapter != nil else { return }
        deleteWhenGone = true
        dismiss()
    }

    /// Its stories move to More stories; none are deleted.
    private func deleteChapter() {
        guard let chapter = context.existing(chapter) else { return }
        let moreStories = Seeder.chapter(forKey: QuestionBank.moreStoriesKey, in: context)
        for story in Array(chapter.stories ?? []) {
            story.chapter = moreStories
        }
        context.delete(chapter)
        try? context.save()
    }
}
