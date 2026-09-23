import SwiftUI

/// A big tappable row: strong outline, icon or photo on the left, words in the
/// middle, and a chevron or play button on the right.
struct TappableRow<Leading: View, Trailing: View>: View {
    private let title: String
    private let detail: String?
    private let accessibilityText: String
    private let action: () -> Void
    private let leading: Leading
    private let trailing: Trailing

    init(
        title: String,
        detail: String?,
        accessibilityText: String,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.accessibilityText = accessibilityText
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 14) {
                leading
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .appFont(.button)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .appFont(.caption)
                            .foregroundStyle(Palette.softInk)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.vertical, 14)
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(shape.fill(Palette.card))
            .overlay(shape.strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder))
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(.isButton)
    }
}

/// A chapter in My life.
struct ChapterRow: View {
    let chapter: Chapter
    let action: () -> Void

    var body: some View {
        let count = chapter.stories?.count ?? 0
        TappableRow(
            title: chapter.name,
            detail: StoryCountText.text(count),
            accessibilityText: "\(chapter.name). \(StoryCountText.text(count)).",
            action: action
        ) {
            Image(systemName: chapter.symbolName)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.marigoldRim)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.marigoldTint))
                .accessibilityHidden(true)
        } trailing: {
            Image(systemName: Symbols.forward)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Palette.softInk)
                .accessibilityHidden(true)
        }
    }
}

/// A story in a chapter or in someone's stories.
struct StoryRow: View {
    let story: Story
    let action: () -> Void

    var body: some View {
        let detail = "\(DayText.toldShort(story.recordedAt)) · \(DurationText.spoken(story.duration))"
        TappableRow(
            title: story.displayTitle,
            detail: detail,
            accessibilityText: "\(story.displayTitle). \(detail). Play.",
            action: action
        ) {
            EmptyView()
        } trailing: {
            PlayDisc(size: 58)
        }
    }
}

/// The round marigold play button used in lists.
struct PlayDisc: View {
    var size: CGFloat

    var body: some View {
        Image(systemName: Symbols.play)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.marigold))
            .overlay(Circle().strokeBorder(Palette.marigoldRim, lineWidth: Metrics.tappableBorder))
            .accessibilityHidden(true)
    }
}

/// A small tappable chip with someone's photo and name.
struct PersonChip: View {
    let person: Person
    let action: () -> Void

    var body: some View {
        let shape = Capsule(style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 10) {
                StoredImage(cacheKey: person.thumbnailCacheKey, data: person.thumbnailData ?? person.photoData)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                Text(person.name)
                    .appFont(.compactButton)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .padding(.leading, 6)
            .padding(.trailing, 20)
            .frame(minHeight: Metrics.minimumTarget)
            .background(shape.fill(Palette.card))
            .overlay(shape.strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder))
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityLabel(Text(person.name))
    }
}
