import SwiftData
import SwiftUI

/// Add or edit a family question, optionally recorded in your own voice.
/// Family questions are asked before the built-in ones.
struct QuestionEditorView: View {
    let question: Question?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ClipPlayer.self) private var clipPlayer
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]
    @Query(sort: \Person.sortOrder) private var people: [Person]

    @State private var text = ""
    @State private var chapter: Chapter?
    @State private var askedBy: Person?
    @State private var recordedAudio: Data?
    @State private var recordedDuration: Double = 0
    @State private var isConfirmingDelete = false
    @State private var hasLoaded = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                TextField("Tell me about…", text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.title3)
            } header: {
                Text("The question")
            } footer: {
                Text("Invite a story instead of testing memory. \u{201C}Tell me about your first car\u{201D} works better than \u{201C}Do you remember your first car?\u{201D} Keep it to one question.")
            }

            Section("Chapter") {
                Picker("Chapter", selection: $chapter) {
                    Text("Decide later").tag(Chapter?.none)
                    ForEach(chapters) { chapter in
                        Text(chapter.name).tag(Optional(chapter))
                    }
                }
            }

            Section {
                Picker("Who's asking?", selection: $askedBy) {
                    Text("No one in particular").tag(Person?.none)
                    ForEach(people) { person in
                        Text(person.name).tag(Optional(person))
                    }
                }
            } footer: {
                Text("He'll see \u{201C}Emily asked this one\u{201D} above the question.")
            }

            Section {
                VoiceClipField(
                    title: "Ask it in your own voice",
                    hint: "Optional. When he taps \u{201C}Read it to me\u{201D}, he'll hear you instead of the iPhone's voice.",
                    clipID: "editor-question",
                    audio: $recordedAudio,
                    duration: $recordedDuration
                )
            }

            if let question, !question.isBuiltIn {
                Section {
                    Button("Delete this question", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } footer: {
                    if question.answerCount > 0 {
                        Text("Stories already told for it are kept.")
                    }
                }
            }
        }
        .familyBackground()
        .navigationTitle(question == nil ? "Add a question" : "Edit question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedText.isEmpty)
            }
        }
        .onAppear(perform: load)
        .onDisappear { clipPlayer.stop() }
        .confirmationDialog("Delete this question?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let question else { return }
        text = question.text
        chapter = question.chapter
        askedBy = question.askedBy
        recordedAudio = question.recordedAudio
    }

    private func save() {
        let target: Question
        if let question {
            target = question
        } else {
            target = Question(text: trimmedText, chapter: nil)
            context.insert(target)
        }
        target.text = trimmedText
        target.chapter = chapter
        target.askedBy = askedBy
        target.recordedAudio = recordedAudio
        try? context.save()
        dismiss()
    }

    private func delete() {
        guard let question else { return }
        context.delete(question)
        try? context.save()
        dismiss()
    }
}
