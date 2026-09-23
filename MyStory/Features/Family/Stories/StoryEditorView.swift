import SwiftData
import SwiftUI

/// Check or fix one story: title, chapter, who's in it, roughly when, and the
/// written words. The recording itself is never changed.
struct StoryEditorView: View {
    let story: Story

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ClipPlayer.self) private var clipPlayer
    @Environment(TranscriptionService.self) private var transcription
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    @State private var title = ""
    @State private var chapter: Chapter?
    @State private var selectedPeople: Set<PersistentIdentifier> = []
    @State private var yearText = ""
    @State private var transcript = ""
    @State private var isConfirmingDelete = false
    @State private var hasLoaded = false

    private var clipID: String { "story-\(story.uuid.uuidString)" }

    var body: some View {
        Form {
            Section {
                Button {
                    clipPlayer.toggle(id: clipID, data: story.audioData)
                } label: {
                    Label(
                        clipPlayer.isPlaying(clipID) ? "Stop" : "Listen (\(DurationText.clock(story.duration)))",
                        systemImage: clipPlayer.isPlaying(clipID) ? "stop.fill" : "play.fill"
                    )
                    .font(.body.weight(.semibold))
                }
                if !story.promptText.isEmpty {
                    LabeledContent("Question", value: story.promptText)
                }
                LabeledContent("Told", value: DayText.long(story.recordedAt))
            }

            Section("Title") {
                TextField("A short title", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.title3)
            }

            Section {
                Picker("Chapter", selection: $chapter) {
                    Text("No chapter").tag(Chapter?.none)
                    ForEach(chapters) { chapter in
                        Text(chapter.name).tag(Optional(chapter))
                    }
                }
                TextField("Roughly what year? (optional)", text: $yearText)
                    .keyboardType(.numberPad)
            }

            Section("Who's in it") {
                PeoplePicker(people: people, selection: $selectedPeople)
            }

            Section {
                TextEditor(text: $transcript)
                    .frame(minHeight: 180)
                transcriptStatus
            } header: {
                Text("His words")
            } footer: {
                Text("Written down on this iPhone. Fix a name or a word if you like; the recording stays exactly as he told it.")
            }

            Section {
                Button("Delete this story", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .familyBackground()
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .onAppear(perform: load)
        .onDisappear { clipPlayer.stop() }
        .onChange(of: story.transcript) { _, newValue in
            // Pick up the words when they arrive, unless the family is editing.
            if transcript.isEmpty { transcript = newValue }
        }
        .confirmationDialog("Delete this story?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete forever", role: .destructive, action: delete)
        } message: {
            Text("The recording will be gone for good. If you're unsure, save a copy first.")
        }
    }

    @ViewBuilder
    private var transcriptStatus: some View {
        switch story.transcriptState {
        case .pending, .working:
            Label("Writing it down…", systemImage: "hourglass")
                .foregroundStyle(Palette.softInk)
        case .failed:
            Button {
                transcription.retranscribe(story)
            } label: {
                Label("Couldn't write it down. Try again", systemImage: "arrow.clockwise")
            }
        case .unavailable:
            Label("This iPhone can't write stories down. You can type the words here.", systemImage: "info.circle")
                .foregroundStyle(Palette.softInk)
        case .done:
            if !story.hasTranscript {
                Button {
                    transcription.retranscribe(story)
                } label: {
                    Label("No words were heard. Try again", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        title = story.title
        chapter = story.chapter
        selectedPeople = Set((story.people ?? []).map(\.persistentModelID))
        yearText = story.year.map { String($0) } ?? ""
        transcript = story.transcript
    }

    private func save() {
        story.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        story.chapter = chapter
        story.people = people.filter { selectedPeople.contains($0.persistentModelID) }
        story.year = Int(yearText.trimmingCharacters(in: .whitespaces))
        let words = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if words != story.transcript.trimmingCharacters(in: .whitespacesAndNewlines) {
            story.transcript = words
            if !words.isEmpty { story.transcriptState = .done }
        }
        story.needsReview = false
        try? context.save()
        dismiss()
    }

    private func delete() {
        clipPlayer.stop()
        context.delete(story)
        try? context.save()
        dismiss()
    }
}
