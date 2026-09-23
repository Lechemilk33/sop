import SwiftData

/// Version 1 of the stored data. Future versions add a new `VersionedSchema`
/// and a migration stage here. With iCloud sync on, changes must be additive.
enum MyStorySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Person.self, Story.self, Chapter.self, Question.self, Photo.self]
    }
}

enum MyStoryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MyStorySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
