import Foundation
import SwiftData

enum ModelContainerFactory {
    /// Placeholder container (CLAUDE.md). Replace before the first TestFlight build.
    static let cloudKitContainerIdentifier = "iCloud.com.example.pitlog"

    /// Private CloudKit database only, no sharing (ADR-1).
    static func production() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )
        return try ModelContainer(
            for: schema, migrationPlan: PitlogMigrationPlan.self, configurations: configuration)
    }

    /// On-device store without sync. Used when the CloudKit-backed store cannot be created.
    static func localOnly() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema, migrationPlan: PitlogMigrationPlan.self, configurations: configuration)
    }

    /// For previews, tests and UI tests.
    static func inMemory() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema, migrationPlan: PitlogMigrationPlan.self, configurations: configuration)
    }
}
