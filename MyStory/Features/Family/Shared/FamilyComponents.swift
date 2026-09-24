import SwiftData
import SwiftUI

/// A row in the family area's menus.
struct FamilyMenuRow: View {
    let title: String
    let systemImage: String
    var badge: Int = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.blue)
                .frame(width: 30)
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            if badge > 0 {
                Text("\(badge)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.brick))
                    .accessibilityLabel("\(badge) to check")
            }
        }
        .padding(.vertical, 6)
    }
}

/// Choose several people with checkmarks.
struct PeoplePicker: View {
    let people: [Person]
    @Binding var selection: Set<PersistentIdentifier>

    var body: some View {
        if people.isEmpty {
            Text("Add people first, from the family area's Add a person.")
                .foregroundStyle(Palette.softInk)
        } else {
            ForEach(people) { person in
                let id = person.persistentModelID
                Button {
                    if selection.contains(id) {
                        selection.remove(id)
                    } else {
                        selection.insert(id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        StoredImage(cacheKey: person.thumbnailCacheKey, data: person.thumbnailData ?? person.photoData, maxPixelSize: 240)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        Text(person.name)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        if selection.contains(id) {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.bold))
                                .foregroundStyle(Palette.blue)
                        }
                    }
                }
                .accessibilityAddTraits(selection.contains(id) ? .isSelected : [])
            }
        }
    }
}

/// Relationship suggestions, written from his point of view.
enum RelationshipSuggestions {
    static let all = [
        "My wife", "My husband", "My partner",
        "My daughter", "My son",
        "My granddaughter", "My grandson",
        "My sister", "My brother",
        "My mother", "My father",
        "My best friend", "My friend",
        "My neighbor", "My doctor", "My caregiver",
    ]
}

extension View {
    /// The family area's calm background behind forms and lists.
    func familyBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Backdrop(tone: nil))
    }
}
