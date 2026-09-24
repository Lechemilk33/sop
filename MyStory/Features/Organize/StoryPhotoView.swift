import PhotosUI
import SwiftData
import SwiftUI

/// Choosing a photo for a story: one of the family's photos, or any photo on
/// the iPhone. "Use no photo" only takes it off the story; the photo itself
/// is kept.
struct StoryPhotoView: View {
    let story: Story

    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \Photo.addedAt, order: .reverse) private var photos: [Photo]

    @State private var pickedItem: PhotosPickerItem?
    @State private var isAdding = false
    @State private var problem: String?

    private let columns = [
        GridItem(.flexible(), spacing: 16, alignment: .top),
        GridItem(.flexible(), spacing: 16, alignment: .top),
    ]

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "A photo for this story", systemImage: Symbols.photo, tone: .marigold)
            if let photo = story.photo {
                WholePhoto(cacheKey: photo.imageCacheKey, data: photo.imageData ?? photo.thumbnailData, maxHeight: 220)
            }
            PhotosPicker(selection: $pickedItem, matching: .images) {
                HStack(spacing: 14) {
                    Image(systemName: Symbols.addPhoto)
                        .font(.system(size: 24, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(isAdding ? "Adding the photo…" : "Choose from my iPhone's photos")
                        .appFont(.compactButton)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassActionStyle(tone: .outline, minHeight: Metrics.compactButtonHeight))
            .disabled(isAdding)
            if let problem {
                Instruction(problem)
            }
            if !photos.isEmpty {
                Text("Or tap one of your family's photos")
                    .appFont(.subtitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(photos) { photo in
                        PhotoChoiceTile(
                            photo: photo,
                            isSelected: story.photo?.persistentModelID == photo.persistentModelID
                        ) {
                            choose(photo)
                        }
                    }
                }
            }
            if story.photo != nil {
                BigButton("Use no photo", systemImage: Symbols.noPhoto, tone: .outline, size: .compact) {
                    choose(nil)
                }
            }
        } footer: {
            BigButton("Done", systemImage: Symbols.done, tone: .marigold, size: .regular) {
                router.pop()
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { await addPhoto(from: item) }
        }
    }

    private func choose(_ photo: Photo?) {
        story.photo = photo
        try? context.save()
    }

    /// A photo from his iPhone becomes one of the family's photos too, with
    /// the story's people and chapter already filled in.
    private func addPhoto(from item: PhotosPickerItem) async {
        isAdding = true
        problem = nil
        defer {
            isAdding = false
            pickedItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let prepared = await Task.detached(priority: .userInitiated, operation: { ImageProcessor.prepare(data) }).value
        else {
            problem = "That photo couldn't be added. Please try another one."
            return
        }
        let photo = Photo(imageData: prepared.full, thumbnailData: prepared.thumbnail)
        context.insert(photo)
        photo.people = story.people ?? []
        photo.chapter = story.chapter
        story.photo = photo
        try? context.save()
    }
}

/// One photo to choose, with a green check when it's the story's photo.
private struct PhotoChoiceTile: View {
    let photo: Photo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            StoredImage(cacheKey: photo.thumbnailCacheKey, data: photo.thumbnailData ?? photo.imageData, placeholderSymbol: Symbols.photo)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(
                        isSelected ? Palette.green : Palette.edge,
                        lineWidth: isSelected ? 4 : Metrics.tappableBorder
                    )
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        SelectedMark(isSelected: true)
                            .background(Circle().fill(Palette.card).padding(3))
                            .padding(8)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityLabel(Text(photo.caption.isEmpty ? "A photo" : photo.caption))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
