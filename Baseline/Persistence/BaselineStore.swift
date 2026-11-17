import Foundation
import SwiftData

/// The single place the app's SwiftData store is described and opened.
enum BaselineStore {
    private typealias BaselineMeasurement = Baseline.Measurement

    /// Shared App Group container URL for the user-data (CloudKit) store.
    static let cloudStoreURL: URL = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.cadre.baseline")!
            .appendingPathComponent("Baseline.store")
    }()

    /// Local-only store (sync bookkeeping). Resolves to SwiftData's default location for
    /// the "BaselineLocal" configuration, so existing installs keep their data.
    static let localStoreURL: URL = ModelConfiguration(
        "BaselineLocal",
        schema: Schema([SyncState.self]),
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
            "BaselineLocal",
            schema: Schema([SyncState.self]),
            url: localStoreURL,
            cloudKitDatabase: .none
        )
        let fullSchema = Schema([
            WeightEntry.self,
            Scan.self,
            BaselineMeasurement.self,
            SyncState.self,
            Goal.self
        ])
        return try ModelContainer(for: fullSchema, configurations: [cloudConfig, localConfig])
    }
}
