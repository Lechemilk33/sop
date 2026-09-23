import PhotosUI
import SwiftData
import SwiftUI

/// Add or edit someone in My people. Changes only apply when you tap Save.
struct PersonEditorView: View {
    let person: Person?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(ClipPlayer.self) private var clipPlayer
    @Environment(StoryRecorder.self) private var recorder
    @Query(sort: \Person.sortOrder) private var people: [Person]

    @State private var name = ""
    @State private var relationship = ""
    @State private var facts: [String] = ["", "", ""]
    @State private var photoData: Data?
    @State private var thumbnailData: Data?
    @State private var helloAudio: Data?
    @State private var helloDuration: Double = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isConfirmingDelete = false
    @State private var hasLoaded = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ownerName: String {
        settings.displayName.isEmpty ? "him" : settings.displayName
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ZStack {
                        StoredImage(cacheKey: "editor-\(person?.uuid.uuidString ?? "new")", data: thumbnailData ?? photoData)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        if isLoadingPhoto {
                            ProgressView()
                        }
                    }
                    Spacer()
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photoData == nil ? "Choose a photo" : "Change photo", systemImage: "photo")
                }
            } header: {
                Text("Photo")
            } footer: {
                Text("A clear, recent photo of their face works best. Real photos are much easier to recognize than drawings.")
            }

            Section("Name") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.title3)
            }

            Section {
                TextField("For example: My daughter", text: $relationship)
                    .textInputAutocapitalization(.sentences)
                Menu {
                    ForEach(RelationshipSuggestions.all, id: \.self) { suggestion in
                        Button(suggestion) { relationship = suggestion }
                    }
                } label: {
                    Label("Choose from a list", systemImage: "list.bullet")
                }
            } header: {
                Text("Who they are to \(ownerName)")
            } footer: {
                Text("Write it the way \(ownerName) would say it: \u{201C}My daughter\u{201D}, \u{201C}My best friend\u{201D}.")
            }

            Section {
                ForEach(0..<3, id: \.self) { index in
                    TextField("Something to remember", text: $facts[index], axis: .vertical)
                        .lineLimit(1...3)
                }
            } header: {
                Text("A few things to remember")
            } footer: {
                Text("Short and simple, like \u{201C}Lives in Chicago with Jake.\u{201D} or \u{201C}Birthday: May 4.\u{201D}")
            }

            Section {
                VoiceClipField(
                    title: "A hello in their own voice",
                    hint: "A few words, like \u{201C}Hi Dad, it\u{2019}s Emily. I love you.\u{201D} He can play it from their page.",
                    clipID: "editor-hello",
                    audio: $helloAudio,
                    duration: $helloDuration
                )
            }

            if person != nil {
                Section {
                    Button("Remove from My people", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
        }
        .familyBackground()
        .navigationTitle(person == nil ? "Add a person" : "Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    // Finish the hello recording first, so it's saved too.
                    .disabled(trimmedName.isEmpty || isLoadingPhoto || recorder.state != .idle)
            }
        }
        .onAppear(perform: load)
        .onDisappear { clipPlayer.stop() }
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
        .confirmationDialog(
            "Remove \(trimmedName) from My people?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: delete)
        } message: {
            Text("Their photo and their hello recording will be deleted. His stories stay; they just won't be linked to \(trimmedName) any more.")
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let person else { return }
        name = person.name
        relationship = person.relationship
        let existing = person.facts
        facts = (0..<3).map { $0 < existing.count ? existing[$0] : "" }
        photoData = person.photoData
        thumbnailData = person.thumbnailData
        helloAudio = person.helloAudio
        helloDuration = person.helloDuration
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let prepared = await Task.detached(priority: .userInitiated) {
            ImageProcessor.prepare(data)
        }.value
        if let prepared {
            photoData = prepared.full
            thumbnailData = prepared.thumbnail
        }
    }

    private func save() {
        let target: Person
        if let person {
            target = person
        } else {
            let nextOrder = (people.map(\.sortOrder).max() ?? -1) + 1
            target = Person(name: trimmedName, relationship: "", sortOrder: nextOrder)
            context.insert(target)
        }
        target.name = trimmedName
        target.relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        target.facts = facts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        target.photoData = photoData
        target.thumbnailData = thumbnailData
        target.helloAudio = helloAudio
        target.helloDuration = helloDuration
        try? context.save()
        dismiss()
    }

    private func delete() {
        guard let person else { return }
        context.delete(person)
        try? context.save()
        dismiss()
    }
}
