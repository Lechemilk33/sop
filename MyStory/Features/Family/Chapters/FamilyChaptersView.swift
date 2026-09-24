import SwiftData
import SwiftUI

/// Every chapter of his stories. Any chapter can be renamed or given another
/// picture; chapters that he or the family made can also be deleted, and
/// their stories move to More stories.
struct FamilyChaptersView: View {
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    var body: some View {
        List {
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
                }
            } footer: {
                Text("He can make chapters and move stories between them himself, from any story's About this story page.")
            }
        }
        .familyBackground()
        .navigationTitle("Chapters")
    }
}

/// Rename a chapter or change its picture. Chapters that aren't built in can
/// be deleted; their stories are never deleted with them.
struct FamilyChapterEditorView: View {
    let chapter: Chapter

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var symbol = ""
    @State private var hasLoaded = false
    @State private var isConfirmingDelete = false

    private var cleanedName: String {
        StoryTitles.cleaned(name)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Chapter name", text: $name)
                    .font(.title3)
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
            if chapter.key.isEmpty {
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
        .navigationTitle("Chapter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(cleanedName.isEmpty)
            }
        }
        .onAppear(perform: load)
        .confirmationDialog("Delete \u{201C}\(chapter.name)\u{201D}?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete chapter", role: .destructive, action: delete)
        } message: {
            Text("No stories are deleted.")
        }
    }

    /// The pictures to choose from, including the chapter's own.
    private var choices: [(symbol: String, name: String)] {
        let all = Symbols.chapterChoices
        guard !all.contains(where: { $0.symbol == chapter.symbolName }) else { return all }
        return [(symbol: chapter.symbolName, name: "As it was")] + all
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        name = chapter.name
        symbol = chapter.symbolName
    }

    private func save() {
        guard !cleanedName.isEmpty else { return }
        chapter.name = cleanedName
        chapter.symbolName = symbol
        try? context.save()
        dismiss()
    }

    private func delete() {
        let moreStories = Seeder.chapter(forKey: QuestionBank.moreStoriesKey, in: context)
        for story in Array(chapter.stories ?? []) {
            story.chapter = moreStories
        }
        context.delete(chapter)
        try? context.save()
        dismiss()
    }
}
