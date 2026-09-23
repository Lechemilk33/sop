import SwiftUI

/// The question, big and clear, with who asked it and any photo or person it's
/// about. The question comes first so it's always visible without scrolling.
struct PromptCard: View {
    let prompt: StoryPrompt

    var body: some View {
        InfoCard(spacing: 14) {
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
            if let person = prompt.aboutPerson {
                PersonBadge(person: person)
            }
            if let photo = prompt.photo {
                StoredImage(cacheKey: photo.imageCacheKey, data: photo.imageData ?? photo.thumbnailData, placeholderSymbol: Symbols.photo)
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

/// Someone's photo, name and what they are to him. Not tappable.
struct PersonBadge: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            StoredImage(cacheKey: person.thumbnailCacheKey, data: person.thumbnailData ?? person.photoData)
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .appFont(.subtitle)
                    .foregroundStyle(Palette.ink)
                if !person.relationship.isEmpty {
                    Text(person.relationship)
                        .appFont(.caption)
                        .foregroundStyle(Palette.softInk)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
