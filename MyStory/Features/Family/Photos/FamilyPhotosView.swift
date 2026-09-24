import PhotosUI
import SwiftData
import SwiftUI

/// Add old photos. Each one becomes a gentle prompt: "Tell me about this photo."
struct FamilyPhotosView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Photo.addedAt, order: .reverse) private var photos: [Photo]

    @State private var selection: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importedCount = 0

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $selection, maxSelectionCount: 30, matching: .images) {
                    FamilyMenuRow(title: "Choose photos", systemImage: "photo.badge.plus")
                }
                .disabled(isImporting)
                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Adding \(importedCount) of \(selection.count)…")
                    }
                }
            } footer: {
                Text("Old photos are wonderful prompts. Each new photo is added as a question: \u{201C}Tell me about this photo.\u{201D} Tap a photo to add who's in it and roughly when.")
            }

            if !photos.isEmpty {
                Section("Photos") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(photos) { photo in
                            NavigationLink {
                                PhotoEditorView(photo: photo)
                            } label: {
                                StoredImage(cacheKey: photo.thumbnailCacheKey, data: photo.thumbnailData, placeholderSymbol: Symbols.photo, maxPixelSize: 320)
                                    .frame(height: 104)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(photo.caption.isEmpty ? "Photo" : photo.caption)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .familyBackground()
        .navigationTitle("Photos")
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        isImporting = true
        importedCount = 0
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let prepared = await Task.detached(priority: .userInitiated, operation: { ImageProcessor.prepare(data) }).value {
                let photo = Photo(imageData: prepared.full, thumbnailData: prepared.thumbnail)
                context.insert(photo)
                let question = Question(text: "Tell me about this photo.", chapter: nil)
                context.insert(question)
                question.photo = photo
            }
            importedCount += 1
        }
        try? context.save()
        isImporting = false
        selection = []
    }
}

/// One photo: who's in it, roughly when, which chapter, and whether to ask him
/// about it.
struct PhotoEditorView: View {
    let photo: Photo

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Chapter.sortOrder) private var chapters: [Chapter]

    @State private var caption = ""
    @State private var yearText = ""
    @State private var chapter: Chapter?
    @State private var selectedPeople: Set<PersistentIdentifier> = []
    @State private var asksAboutIt = true
    @State private var isConfirmingDelete = false
    /// Deleted only once the editor has closed, so nothing on screen is
    /// still showing the photo when it's removed.
    @State private var deleteWhenGone = false
    @State private var hasLoaded = false

    private var yearIsValid: Bool {
        yearText.trimmingCharacters(in: .whitespaces).isEmpty || StoryYears.parse(yearText) != nil
    }

    var body: some View {
        Form {
            Section {
                // The whole photo, never cropped, so everyone in it can be seen.
                StoredImage(
                    cacheKey: photo.imageCacheKey,
                    data: photo.imageData ?? photo.thumbnailData,
                    placeholderSymbol: Symbols.photo,
                    contentMode: .fit,
                    maxPixelSize: ImageCache.largePixels
                )
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            Section {
                TextField("A few words, like \u{201C}The lake house, summer\u{201D}", text: $caption, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Roughly what year? (optional)", text: $yearText)
                    .keyboardType(.numberPad)
                Picker("Chapter", selection: $chapter) {
                    Text("Decide later").tag(Chapter?.none)
                    ForEach(chapters) { chapter in
                        Text(chapter.name).tag(Optional(chapter))
                    }
                }
            } header: {
                Text("About this photo")
            } footer: {
                if !yearIsValid {
                    Text("Use four digits, like 1975.")
                        .foregroundStyle(Palette.brick)
                }
            }
            Section("Who's in it") {
                PeoplePicker(people: people, selection: $selectedPeople)
            }
            Section {
                Toggle("Ask \(settings.displayName.isEmpty ? "him" : settings.displayName) about this photo", isOn: $asksAboutIt)
            } footer: {
                Text("It will come up in Tell a story as \u{201C}Tell me about this photo.\u{201D}")
            }
            Section {
                Button("Delete photo", role: .destructive) {
                    isConfirmingDelete = true
                }
            } footer: {
                Text("Stories he told about it are kept.")
            }
        }
        .familyBackground()
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!yearIsValid)
            }
        }
        .onAppear(perform: load)
        .onDisappear {
            if deleteWhenGone {
                context.delete(photo)
                try? context.save()
            }
        }
        .confirmationDialog("Delete this photo?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        } message: {
            Text("The photo and its question are removed. Stories he told about it are kept, without the photo.")
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        caption = photo.caption
        yearText = photo.year.map { String($0) } ?? ""
        chapter = photo.chapter
        selectedPeople = Set((photo.people ?? []).map(\.persistentModelID))
        asksAboutIt = photo.promptQuestion.map { !$0.isHidden } ?? false
    }

    private func save() {
        photo.caption = StoryTitles.cleaned(caption)
        photo.year = StoryYears.parse(yearText)
        photo.chapter = context.existing(chapter)
        photo.people = people.filter { selectedPeople.contains($0.persistentModelID) }
        if let existing = photo.promptQuestion {
            // Switched off, the question is only hidden, so the stories he
            // told about the photo stay linked to it and it isn't asked anew.
            existing.isHidden = !asksAboutIt
            existing.chapter = photo.chapter
        } else if asksAboutIt {
            let question = Question(text: "Tell me about this photo.", chapter: nil)
            context.insert(question)
            question.photo = photo
            question.chapter = photo.chapter
        }
        try? context.save()
        dismiss()
    }

    private func delete() {
        deleteWhenGone = true
        dismiss()
    }
}
