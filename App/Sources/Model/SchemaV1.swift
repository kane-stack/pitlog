import SwiftData

/// SchemaV1 may still change freely until the first TestFlight build. From then on it is frozen:
/// every change needs a new `VersionedSchema` and a stage in `PitlogMigrationPlan`.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Vehicle.self, OdometerReading.self, Reminder.self]
    }
}

enum PitlogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
