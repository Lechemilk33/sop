import SwiftData
import SwiftUI

/// The important people in his life: real photos, names, and what they are
/// to him. The family adds people from the Family area.
struct MyPeopleView: View {
    @Environment(Router.self) private var router
    @Query(sort: \Person.sortOrder) private var people: [Person]

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "My people", systemImage: Symbols.people, tone: .blue)
            if people.isEmpty {
                EmptyStateMessage(
                    title: "No one here yet",
                    message: "Your family will add the people in your life, with their photos."
                )
            } else {
                Instruction("Tap someone to see more.")
                PeopleGrid(people: people) { person in
                    router.remember(person.persistentModelID)
                    router.push(.person(person))
                }
            }
        }
    }
}

/// People in two columns (one with very large text), each a photo card.
struct PeopleGrid: View {
    let people: [Person]
    var selected: Set<PersistentIdentifier>?
    let action: (Person) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
        LazyVGrid(columns: columns, spacing: Metrics.itemSpacing) {
            ForEach(people) { person in
                PersonCard(
                    person: person,
                    isSelected: selected.map { $0.contains(person.persistentModelID) }
                ) {
                    action(person)
                }
                .id(person.persistentModelID)
            }
        }
    }
}

/// A person's framed photo with their name and relationship underneath.
/// When choosing people for a story, a chosen card shows a green check.
struct PersonCard: View {
    let person: Person
    var isSelected: Bool?
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
        let chosen = isSelected ?? false
        Button {
            TapGuard.perform(action)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                StoredImage(cacheKey: person.thumbnailCacheKey, data: person.thumbnailData ?? person.photoData)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if isSelected == true {
                            SelectedMark(isSelected: true)
                                .padding(8)
                        }
                    }
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
            .background(shape.fill(chosen ? Palette.greenTint : Palette.card))
            .overlay(
                shape.strokeBorder(
                    contrast == .increased ? Palette.ink : (chosen ? Palette.green : Palette.edge),
                    lineWidth: chosen || contrast == .increased ? Metrics.increasedContrastBorder : Metrics.tappableBorder
                )
            )
            .shadow(color: Palette.ink.opacity(0.06), radius: 10, y: 3)
            .contentShape(shape)
        }
        .buttonStyle(PressDimStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(person.relationship.isEmpty ? person.name : "\(person.name), \(person.relationship)"))
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }
}
