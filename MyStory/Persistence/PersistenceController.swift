import Foundation
import SwiftData

/// Creates the store that holds every story, person and photo.
enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MyStorySchemaV1.self)
        let configuration = ModelConfiguration(
            "MyStory",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: inMemory ? .none : CloudSync.database
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: MyStoryMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

/// iCloud backup is off until the family turns it on (it needs the paid Apple
/// Developer Program). See README → "Turn on iCloud backup".
enum CloudSync {
    /// `MYSTORY_ICLOUD_SYNC` build setting, passed through Info.plist.
    static var isEnabled: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MyStoryICloudSync") as? String else { return false }
        return ["yes", "true", "1"].contains(value.lowercased())
    }

    static var containerIdentifier: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MyStoryCloudKitContainer") as? String,
              value.hasPrefix("iCloud."), !value.contains("$(") else { return nil }
        return value
    }

    static var database: ModelConfiguration.CloudKitDatabase {
        guard isEnabled, let containerIdentifier else { return .none }
        return .private(containerIdentifier)
    }
}
