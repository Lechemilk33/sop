import SwiftUI

/// The question, big and clear, with who asked it and any photo it's about.
struct PromptCard: View {
    let prompt: StoryPrompt

    var body: some View {
        InfoCard(spacing: 14) {
            if let photo = prompt.photo {
                StoredImage(cacheKey: photo.imageCacheKey, data: photo.imageData ?? photo.thumbnailData, placeholderSymbol: Symbols.photo)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if let person = prompt.aboutPerson {
                HStack(spacing: 12) {
                    StoredImage(cacheKey: person.thumbnailCacheKey, data: person.thumbnailData ?? person.photoData)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    Text(person.name)
                        .appFont(.subtitle)
                        .foregroundStyle(Palette.ink)
                }
            }
            if let asker = prompt.askedByName {
                Label {
                    Text("\(asker) asked this one")
                        .appFont(.caption)
                } icon: {
                    Image(systemName: Symbols.askedBy)
                        .font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Palette.marigoldTint))
            }
            Text("Here's a question")
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
            Text(prompt.text)
                .appFont(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
