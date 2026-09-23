import SwiftData
import SwiftUI

/// Everyone in My people, in the order he sees them. Drag to reorder.
struct FamilyPeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.sortOrder) private var people: [Person]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PersonEditorView(person: nil)
                } label: {
                    FamilyMenuRow(title: "Add a person", systemImage: "person.crop.circle.badge.plus")
                }
            }
            Section {
                ForEach(people) { person in
                    NavigationLink {
                        PersonEditorView(person: person)
                    } label: {
                        HStack(spacing: 14) {
                            StoredImage(cacheKey: person.thumbnailCacheKey, data: person.thumbnailData ?? person.photoData)
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.body.weight(.semibold))
                                if !person.relationship.isEmpty {
                                    Text(person.relationship)
                                        .font(.subheadline)
                                        .foregroundStyle(Palette.softInk)
                                }
                            }
                        }
                    }
                }
                .onMove(perform: move)
            } header: {
                Text("In My people")
            } footer: {
                if people.count > 1 {
                    Text("Tap Edit to change the order. The people he sees most should come first.")
                }
            }
        }
        .familyBackground()
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if people.count > 1 {
                    EditButton()
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = people
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, person) in ordered.enumerated() {
            person.sortOrder = index
        }
        try? context.save()
    }
}
