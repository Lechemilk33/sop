import PhotosUI
import SwiftData
import SwiftUI

/// Check or fix one story: title, chapter, who's in it, its photo, roughly
/// when, and the written words. The recording itself is never changed.
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
    @State private var photo: Photo?
    @State private var photoItem: PhotosPickerItem?
    @State private var isAddingPhoto = false
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
                // Every story lives in a chapter, so it can always be found in My life.
                Picker("Chapter", selection: $chapter) {
                    ForEach(chapters) { chapter in
                        Text(chapter.name).tag(Optional(chapter))
                    }
                }
                TextField("Roughly what year? (optional)", text: $yearText)
                    .keyboardType(.numberPad)
            }

            Section {
                if let photo {
                    StoredImage(
                        cacheKey: photo.imageCacheKey,
                        data: photo.imageData ?? photo.thumbnailData,
                        placeholderSymbol: Symbols.photo,
                        contentMode: .fit,
                        maxPixelSize: ImageCache.largePixels
                    )
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(isAddingPhoto ? "Adding the photo…" : (photo == nil ? "Choose a photo" : "Choose another photo"), systemImage: "photo.badge.plus")
                }
                .disabled(isAddingPhoto)
                if photo != nil {
                    Button("Use no photo", role: .destructive) {
                        photo = nil
                    }
                }
            } header: {
                Text("Photo")
            } footer: {
                Text("A photo he sees while he listens. It's also added to the family's photos, so he can choose it for other stories. He can pick from those himself, too.")
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
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await addPhoto(from: item) }
        }
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
        chapter = story.chapter ?? chapters.first { $0.key == QuestionBank.moreStoriesKey }
        selectedPeople = Set((story.people ?? []).map(\.persistentModelID))
        yearText = story.year.map { String($0) } ?? ""
        transcript = story.transcript
        photo = story.photo
    }

    /// A new photo from the iPhone joins the family's photos and this story.
    private func addPhoto(from item: PhotosPickerItem) async {
        isAddingPhoto = true
        defer {
            isAddingPhoto = false
            photoItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let prepared = await Task.detached(priority: .userInitiated, operation: { ImageProcessor.prepare(data) }).value
        else { return }
        let newPhoto = Photo(imageData: prepared.full, thumbnailData: prepared.thumbnail)
        context.insert(newPhoto)
        try? context.save()
        photo = newPhoto
    }

    private func save() {
        story.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let chapter {
            story.chapter = chapter
        }
        story.people = people.filter { selectedPeople.contains($0.persistentModelID) }
        story.photo = context.existing(photo)
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
