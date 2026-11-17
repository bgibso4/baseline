import Foundation
import SwiftData

/// The single place the app's SwiftData store is described and opened.
enum BaselineStore {
    private typealias BaselineMeasurement = Baseline.Measurement

    /// Configuration name of the local-only store. SwiftData derives its default file
    /// location from this name, so it must never change.
    private static let localConfigurationName = "BaselineLocal"

    /// Models kept in the local-only store (sync bookkeeping, never synced to iCloud).
    private static var localSchema: Schema { Schema([SyncState.self]) }

    /// Shared App Group container URL for the user-data (CloudKit) store.
    static let cloudStoreURL: URL = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.cadre.baseline")!
            .appendingPathComponent("Baseline.store")
    }()

    /// Local-only store (sync bookkeeping). Resolves to SwiftData's default location for
    /// the "BaselineLocal" configuration, so existing installs keep their data.
    static let localStoreURL: URL = ModelConfiguration(
        localConfigurationName,
        schema: localSchema,
        cloudKitDatabase: .none
    ).url

    static func makeContainer(
        cloudStoreURL: URL,
        localStoreURL: URL,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) throws -> ModelContainer {
        // User data: syncs to iCloud via CloudKit.
        let cloudConfig = ModelConfiguration(
            "Baseline",
            schema: Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self, Goal.self]),
            url: cloudStoreURL,
            cloudKitDatabase: cloudKitDatabase
        )
        // Local-only: sync bookkeeping, never synced to iCloud.
        let localConfig = ModelConfiguration(
            localConfigurationName,
            schema: localSchema,
            url: localStoreURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: Schema(versionedSchema: BaselineSchemaV1.self),
            migrationPlan: BaselineMigrationPlan.self,
            configurations: [cloudConfig, localConfig]
        )
    }
}
