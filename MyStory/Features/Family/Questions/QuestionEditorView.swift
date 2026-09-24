import SwiftData
import SwiftUI

/// Add or edit a family question, optionally recorded in your own voice.
/// Family questions are asked before the built-in ones.
struct QuestionEditorView: View {
    let question: Question?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ClipPlayer.self) private var clipPlayer
    @Environment(StoryRecorder.self) private var recorder
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]
    @Query(sort: \Person.sortOrder) private var people: [Person]

    @State private var text = ""
    @State private var chapter: Chapter?
    @State private var askedBy: Person?
    @State private var recordedAudio: Data?
    @State private var recordedDuration: Double = 0
    @State private var isConfirmingDelete = false
    /// Deleted only once the editor has closed, so nothing on screen is
    /// still showing the question when it's removed.
    @State private var deleteWhenGone = false
    @State private var hasLoaded = false

    /// One question, on one line, not too long to read on his screen.
    private var trimmedText: String {
        String(text.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(200))
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
                Text("Invite a story instead of testing memory. \u{201C}Tell me about a car you loved\u{201D} works better than \u{201C}Do you remember your first car?\u{201D} Keep it to one question, and ask about long ago rather than this week.")
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
                    // Finish recording the question first, so it's saved too.
                    .disabled(trimmedText.isEmpty || recorder.state != .idle)
            }
        }
        .onAppear(perform: load)
        .onDisappear {
            clipPlayer.stop()
            // A question still being recorded when the editor closes isn't kept.
            Task { await recorder.discardClip() }
            if deleteWhenGone, let question {
                context.delete(question)
                try? context.save()
            }
        }
        .confirmationDialog("Delete this question?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        } message: {
            Text("It won't be asked again. Stories already told for it are kept.")
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
        target.chapter = context.existing(chapter)
        target.askedBy = context.existing(askedBy)
        if target.recordedAudio != recordedAudio { target.recordedAudio = recordedAudio }
        try? context.save()
        dismiss()
    }

    private func delete() {
        guard question != nil else { return }
        clipPlayer.stop()
        deleteWhenGone = true
        dismiss()
    }
}
