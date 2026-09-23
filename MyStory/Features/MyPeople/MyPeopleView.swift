import SwiftData
import SwiftUI

/// The important people in his life: real photos, names, and what they are
/// to him. The family adds people from the Family area.
struct MyPeopleView: View {
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Person.sortOrder) private var people: [Person]

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: Metrics.itemSpacing, alignment: .top),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
        ScreenScaffold {
            SectionHeader(title: "My people", systemImage: Symbols.people, tone: .blue)
            if people.isEmpty {
                EmptyStateMessage(
                    title: "No one here yet",
                    message: "Your family will add the people in your life, with their photos."
                )
            } else {
                Text("Tap a photo to see more.")
                    .appFont(.bodyBold)
                    .foregroundStyle(Palette.softInk)
                LazyVGrid(columns: columns, spacing: Metrics.itemSpacing) {
                    ForEach(people) { person in
                        PersonCard(person: person) {
                            router.push(.person(person))
                        }
                    }
                }
            }
        }
    }
}

/// A person's photo with their name and relationship underneath.
private struct PersonCard: View {
    let person: Person
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button {
            TapGuard.perform(action)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                StoredImage(cacheKey: person.thumbnailCacheKey, data: person.thumbnailData ?? person.photoData)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(person.name)
                    .appFont(.button)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !person.relationship.isEmpty {
                    Text(person.relationship)
                        .appFont(.caption)
                        .foregroundStyle(Palette.softInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Palette.card))
            .overlay(shape.strokeBorder(Palette.edge, lineWidth: Metrics.tappableBorder))
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(person.relationship.isEmpty ? person.name : "\(person.name), \(person.relationship)"))
        .accessibilityAddTraits(.isButton)
    }
}
