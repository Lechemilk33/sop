import Foundation
import SwiftData

/// People added before portraits were framed around the face get their photo
/// framed once, so no one's head is cut off in My people. Runs at launch.
/// A portrait that's already square was framed by the app or by the family
/// (on this iPhone or another), so it's never touched.
@MainActor
enum PortraitRefresh {
    private static let versionKey = "portraitFramingVersion"
    private static let currentVersion = 1

    static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) async {
        guard defaults.integer(forKey: versionKey) < currentVersion else { return }
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let work = people.compactMap { person -> (id: PersistentIdentifier, photo: Data)? in
            guard let photo = person.photoData, !Self.isFramed(person.thumbnailData) else { return nil }
            return (id: person.persistentModelID, photo: photo)
        }
        for item in work {
            let photo = item.photo
            let framed = await Task.detached(priority: .utility) {
                ImageProcessor.framedPortrait(fromFull: photo)
            }.value
            // The family may have changed or removed this person meanwhile.
            guard let framed, let person = Self.person(item.id, in: context), person.photoData == photo else { continue }
            person.thumbnailData = framed
        }
        try? context.save()
        defaults.set(currentVersion, forKey: versionKey)
    }

    /// Framed portraits are square; the old thumbnails kept the photo's shape.
    private static func isFramed(_ thumbnail: Data?) -> Bool {
        guard let thumbnail, let size = ImageProcessor.pixelSize(of: thumbnail) else { return false }
        return abs(size.width - size.height) <= 1
    }

    private static func person(_ id: PersistentIdentifier, in context: ModelContext) -> Person? {
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
