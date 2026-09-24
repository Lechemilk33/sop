import Foundation
import SwiftData

/// People added before portraits were framed around the face get their photo
/// framed once, so no one's head is cut off in My people. Runs at launch.
@MainActor
enum PortraitRefresh {
    private static let versionKey = "portraitFramingVersion"
    private static let currentVersion = 1

    static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) async {
        guard defaults.integer(forKey: versionKey) < currentVersion else { return }
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let work = people.compactMap { person in
            person.photoData.map { (id: person.persistentModelID, photo: $0) }
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

    private static func person(_ id: PersistentIdentifier, in context: ModelContext) -> Person? {
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
