import SwiftData
import SwiftUI

/// Choosing a photo for a story from the family's photos, the ones with the
/// story's people or chapter first. "Use no photo" only takes it off the
/// story; the photo itself is kept. New photos come in through the family
/// area, so he never meets the iPhone's own photo picker.
struct StoryPhotoView: View {
    let story: Story

    @Environment(Router.self) private var router
    @Query(sort: \Photo.addedAt, order: .reverse) private var photos: [Photo]

    @State private var showsAll = false
    /// The photo the story had when he came in. It stays first, so nothing
    /// moves around when he taps a different one.
    @State private var photoAtStart: PersistentIdentifier?
    @State private var hasLoaded = false

    /// How many photos show before "Show more photos".
    private let firstCount = 6

    private let columns = [
        GridItem(.flexible(), spacing: 16, alignment: .top),
        GridItem(.flexible(), spacing: 16, alignment: .top),
    ]

    var body: some View {
        let ordered = relevantFirst
        let shown = showsAll ? ordered : Array(ordered.prefix(firstCount))
        ScreenScaffold {
            SectionHeader(title: "A photo for this story", systemImage: Symbols.photo, tone: .marigold)
            CurrentName(story: story)
            if photos.isEmpty {
                EmptyStateMessage(
                    title: "No photos yet",
                    message: "Ask your family to add some old photos. Then you can choose one here."
                )
            } else {
                Instruction(story.photo == nil ? "Tap a photo to add it to this story." : "Tap another photo to use it instead.")
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(shown) { photo in
                        PhotoChoiceTile(
                            photo: photo,
                            isSelected: story.photo?.persistentModelID == photo.persistentModelID
                        ) {
                            choose(photo)
                        }
                    }
                }
                if !showsAll, ordered.count > firstCount {
                    BigButton("Show more photos", systemImage: Symbols.photo, tone: .outline, size: .compact) {
                        showsAll = true
                    }
                }
                if story.photo != nil {
                    BigButton("Use no photo", systemImage: Symbols.noPhoto, tone: .outline, size: .compact) {
                        choose(nil)
                    }
                }
            }
        } footer: {
            BigButton("Done", systemImage: Symbols.done, tone: .marigold, size: .regular) {
                router.pop()
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            photoAtStart = story.photo?.persistentModelID
        }
    }

    /// The story's own photo first, where he can see it's chosen; then
    /// photos with the story's people, then ones in its chapter, then the
    /// rest, newest first within each.
    private var relevantFirst: [Photo] {
        let peopleIDs = Set((story.people ?? []).map(\.persistentModelID))
        let chapterID = story.chapter?.persistentModelID
        let firstID = hasLoaded ? photoAtStart : story.photo?.persistentModelID
        func rank(_ photo: Photo) -> Int {
            if photo.persistentModelID == firstID { return -1 }
            if (photo.people ?? []).contains(where: { peopleIDs.contains($0.persistentModelID) }) { return 0 }
            if let chapterID, photo.chapter?.persistentModelID == chapterID { return 1 }
            return 2
        }
        return photos.enumerated()
            .sorted { lhs, rhs in
                let left = rank(lhs.element)
                let right = rank(rhs.element)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    private func choose(_ photo: Photo?) {
        story.photo = photo
        try? story.modelContext?.save()
    }
}

/// One photo to choose, shown whole, marked "Chosen" when it's the story's.
private struct PhotoChoiceTile: View {
    let photo: Photo
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            StoredImage(
                cacheKey: photo.thumbnailCacheKey,
                data: photo.thumbnailData ?? photo.imageData,
                placeholderSymbol: Symbols.photo,
                contentMode: .fit
            )
            .aspectRatio(1, contentMode: .fit)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    isSelected ? Palette.green : (contrast == .increased ? Palette.ink : Palette.edge),
                    lineWidth: isSelected ? 4 : (contrast == .increased ? Metrics.increasedContrastBorder : Metrics.tappableBorder)
                )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    SelectedMark(isSelected: true)
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
