import SwiftUI

/// A big tappable row: a white card with a clear edge, an icon or photo on
/// the left, words in the middle, and a chevron, check or play button on the
/// right. Rows are content, so they're solid rather than glass.
struct TappableRow<Leading: View, Trailing: View>: View {
    private let eyebrow: String?
    private let title: String
    private let detail: String?
    private let accessibilityText: String
    private let isSelected: Bool
    private let action: () -> Void
    private let leading: Leading
    private let trailing: Trailing

    @Environment(\.colorSchemeContrast) private var contrast

    init(
        eyebrow: String? = nil,
        title: String,
        detail: String?,
        accessibilityText: String,
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.accessibilityText = accessibilityText
        self.isSelected = isSelected
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            HStack(spacing: 16) {
                leading
                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow {
                        Text(eyebrow)
                            .appFont(.caption)
                            .foregroundStyle(Palette.softInk)
                    }
                    Text(title)
                        .appFont(.button)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .appFont(.caption)
                            .foregroundStyle(Palette.softInk)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.vertical, 14)
            .padding(.leading, 14)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(shape.fill(isSelected ? Palette.greenTint : Palette.card))
            .overlay(shape.strokeBorder(edgeColor, lineWidth: edgeWidth))
            .shadow(color: Palette.ink.opacity(0.06), radius: 10, y: 3)
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var edgeColor: Color {
        if contrast == .increased { return Palette.ink }
        return isSelected ? Palette.green : Palette.edge
    }

    private var edgeWidth: CGFloat {
        if contrast == .increased || isSelected { return Metrics.increasedContrastBorder }
        return Metrics.tappableBorder
    }
}

/// The chevron that means "this opens another screen".
struct RowChevron: View {
    var body: some View {
        Image(systemName: Symbols.forward)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Palette.softInk)
            .accessibilityHidden(true)
    }
}

/// "Chosen", with a check, on a chosen row, person or photo; an empty
/// circle on the others. Screen readers hear "selected" from the row itself.
struct SelectedMark: View {
    let isSelected: Bool

    var body: some View {
        if isSelected {
            Label("Chosen", systemImage: Symbols.done)
                .appFont(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.green))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Palette.edge)
                .accessibilityHidden(true)
        }
    }
}

/// A chapter in My stories.
struct ChapterRow: View {
    let chapter: Chapter
    var isSelected: Bool? = nil
    let action: () -> Void

    var body: some View {
        let count = chapter.stories?.count ?? 0
        TappableRow(
            title: chapter.name,
            detail: StoryCountText.text(count),
            accessibilityText: "\(chapter.name). \(StoryCountText.text(count)).",
            isSelected: isSelected ?? false,
            action: action
        ) {
            Medallion(systemImage: chapter.symbolName, tone: .marigold, size: Metrics.smallMedallion)
        } trailing: {
            if let isSelected {
                SelectedMark(isSelected: isSelected)
            } else {
                RowChevron()
            }
        }
    }
}

/// A story in a chapter or in someone's stories.
struct StoryRow: View {
    let story: Story
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let detail = "\(DayText.toldShort(story.recordedAt)) · \(DurationText.spoken(story.duration))"
        TappableRow(
            title: story.displayTitle,
            detail: detail,
            accessibilityText: "\(story.displayTitle). \(detail). Play.",
            action: action
        ) {
            // With very large text, the words need the room more.
            if let photo = story.photo, !dynamicTypeSize.isAccessibilitySize {
                StoredImage(cacheKey: photo.thumbnailCacheKey, data: photo.thumbnailData ?? photo.imageData, placeholderSymbol: Symbols.photo)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        } trailing: {
            PlayDisc(size: 56)
        }
    }
}

/// The round gold play button used in lists.
struct PlayDisc: View {
    var size: CGFloat

    var body: some View {
        Image(systemName: Symbols.play)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .offset(x: size * 0.03)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.marigold))
            .overlay(Circle().strokeBorder(Palette.marigoldRim, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}
