import PhotosUI
import SwiftData
import SwiftUI
import UIKit

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
    @State private var isChoosingPhoto = false
    @State private var isTakingPhoto = false
    @State private var framingSession: FramingSession?
    /// A photo just taken, waiting for the camera to close before it's used.
    @State private var takenPhoto: UIImage?
    @State private var isLoadingPhoto = false
    @State private var photoProblem: String?
    @State private var isConfirmingDelete = false
    /// Deleted only once the editor has closed, so nothing on screen is
    /// still showing the person when they're removed.
    @State private var deleteWhenGone = false
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
                VStack(spacing: 12) {
                    Menu {
                        Button {
                            isChoosingPhoto = true
                        } label: {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        }
                        if CameraPicker.isAvailable {
                            Button {
                                isTakingPhoto = true
                            } label: {
                                Label("Take a Photo", systemImage: "camera")
                            }
                        }
                        if photoData != nil {
                            Button {
                                Task { await startFraming() }
                            } label: {
                                Label("Move and Zoom", systemImage: "crop")
                            }
                            Button {
                                Task { await showWholePhoto() }
                            } label: {
                                Label("Show Whole Photo", systemImage: "rectangle.center.inset.filled")
                            }
                            Button(role: .destructive) {
                                photoProblem = nil
                                photoData = nil
                                thumbnailData = nil
                            } label: {
                                Label("Remove Photo", systemImage: "trash")
                            }
                        }
                    } label: {
                        portraitPreview
                    }
                    // Not while a hello is being recorded: the camera would
                    // cover this page and end the recording.
                    .disabled(isLoadingPhoto || recorder.state != .idle)
                    .accessibilityLabel(photoData == nil ? "Add a photo" : "Change the photo")
                    Text(photoData == nil ? "Tap to add a photo" : "Tap the photo to change it, or to move and zoom it")
                        .font(.subheadline)
                        .foregroundStyle(Palette.softInk)
                        .multilineTextAlignment(.center)
                    if let photoProblem {
                        Text(photoProblem)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.brick)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } header: {
                Text("Photo")
            } footer: {
                Text("A clear, recent photo of their face works best. The app frames it around their face; use Move and Zoom to adjust it.")
            }

            Section("Name") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.title3)
                    .onChange(of: name) { _, newValue in
                        if newValue.count > Self.longestName { name = String(newValue.prefix(Self.longestName)) }
                    }
            }

            Section {
                TextField("For example: My daughter", text: $relationship)
                    .textInputAutocapitalization(.sentences)
                    .onChange(of: relationship) { _, newValue in
                        if newValue.count > Self.longestName { relationship = String(newValue.prefix(Self.longestName)) }
                    }
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
        .onDisappear {
            clipPlayer.stop()
            // A hello still being recorded when the editor closes isn't kept.
            Task { await recorder.discardClip() }
            if deleteWhenGone, let person {
                context.delete(person)
                try? context.save()
            }
        }
        .photosPicker(isPresented: $isChoosingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .fullScreenCover(isPresented: $isTakingPhoto, onDismiss: useTakenPhoto) {
            CameraPicker(
                onPicked: { image in
                    takenPhoto = image
                    isTakingPhoto = false
                },
                onCancel: { isTakingPhoto = false }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $framingSession) { session in
            PhotoFramingView(session: session) { framing in
                Task { await applyFraming(framing, to: session.photoData) }
            }
        }
        .confirmationDialog(
            "Remove \(savedName) from My people?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: delete)
        } message: {
            Text("Their photo and their hello recording will be deleted. His stories and photos stay; they just won't show \(savedName) any more.")
        }
    }

    /// Names and relationships are short; a long paste is cut to this.
    private static let longestName = 60

    /// The name as it's saved, not as it's being typed.
    private var savedName: String {
        let saved = person?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? "this person" : saved
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

    /// The framed square he'll see, with a "Change" badge.
    private var portraitPreview: some View {
        ZStack {
            StoredImage(cacheKey: "editor-\(person?.uuid.uuidString ?? "new")", data: thumbnailData ?? photoData)
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder)
                )
            if isLoadingPhoto {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .overlay(alignment: .bottom) {
            Label(photoData == nil ? "Add" : "Change", systemImage: photoData == nil ? "plus" : "pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Palette.blue))
                .offset(y: 14)
        }
        .padding(.bottom, 14)
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        // Busy from the start: a photo from iCloud can take a while to arrive,
        // and Save must wait for it.
        isLoadingPhoto = true
        photoProblem = nil
        defer {
            isLoadingPhoto = false
            photoItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            photoProblem = "That photo couldn't be opened. Please try another one."
            return
        }
        await usePhoto(data)
    }

    /// A new photo: framed around their face, then the family adjusts it.
    /// It only replaces the old photo once they tap Use Photo.
    private func usePhoto(_ data: Data) async {
        isLoadingPhoto = true
        photoProblem = nil
        defer { isLoadingPhoto = false }
        guard let prepared = await Task.detached(priority: .userInitiated, operation: { ImageProcessor.preparePortrait(data) }).value,
              let image = UIImage(data: prepared.full) else {
            photoProblem = "That photo couldn't be used. Please try another one."
            return
        }
        framingSession = FramingSession(image: image, photoData: prepared.full, framing: prepared.framing, automatic: prepared.framing)
    }

    /// Once the camera has closed, the photo is prepared in the background
    /// and then framed.
    private func useTakenPhoto() {
        guard let image = takenPhoto else { return }
        takenPhoto = nil
        isLoadingPhoto = true
        Task {
            let data = await Task.detached(priority: .userInitiated) {
                image.jpegData(compressionQuality: 0.9)
            }.value
            isLoadingPhoto = false
            guard let data else {
                photoProblem = "That photo couldn't be used. Please try again."
                return
            }
            await usePhoto(data)
        }
    }

    /// The whole photo in the square, for when cropping would cut someone out.
    private func showWholePhoto() async {
        guard let photoData else { return }
        let full = photoData
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        if let whole = await Task.detached(priority: .userInitiated, operation: { ImageProcessor.wholePortrait(from: full) }).value {
            thumbnailData = whole
        }
    }

    /// Move and zoom the photo that's already there.
    private func startFraming() async {
        guard let photoData else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        let full = photoData
        guard let framing = await Task.detached(priority: .userInitiated, operation: { ImageProcessor.automaticFraming(for: full) }).value,
              let image = UIImage(data: full) else { return }
        framingSession = FramingSession(image: image, photoData: full, framing: framing, automatic: framing)
    }

    /// Use Photo: the photo that was framed, and its square.
    private func applyFraming(_ framing: PortraitFraming, to full: Data) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        guard let portrait = await Task.detached(priority: .userInitiated, operation: { ImageProcessor.portrait(from: full, framing: framing) }).value else {
            photoProblem = "That photo couldn't be used. Please try another one."
            return
        }
        photoData = full
        thumbnailData = portrait
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
        // Photos and recordings are only written if they changed, so an
        // edited name doesn't copy them all again (or send them to iCloud).
        if target.photoData != photoData { target.photoData = photoData }
        if target.thumbnailData != thumbnailData { target.thumbnailData = thumbnailData }
        if target.helloAudio != helloAudio { target.helloAudio = helloAudio }
        if target.helloDuration != helloDuration { target.helloDuration = helloDuration }
        try? context.save()
        dismiss()
    }

    private func delete() {
        guard person != nil else { return }
        clipPlayer.stop()
        deleteWhenGone = true
        dismiss()
    }
}
