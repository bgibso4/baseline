import CoreData
import XCTest
@testable import Baseline

/// Proves opening the f66afa8 stores with the versioned schema is a no-op on the model: the
/// per-entity version hashes Core Data stamps into each store's metadata are identical before
/// and after the open. A difference would mean nesting the models in `BaselineSchemaV1`
/// changed the model and SwiftData silently migrated users' stores.
final class SchemaV1VersionHashTests: XCTestCase {
    func testOpeningF66afa8StoresLeavesEntityVersionHashesUnchanged() throws {
        let fixture = try FixtureStore.copyFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let cloudBefore = try versionHashes(at: fixture.cloudStoreURL)
        let localBefore = try versionHashes(at: fixture.localStoreURL)
        // Each store's metadata records the whole container model, so check inclusion, not equality.
        XCTAssertTrue(Set(["WeightEntry", "Scan", "Measurement", "Goal"]).isSubset(of: cloudBefore.keys))
        XCTAssertTrue(localBefore.keys.contains("SyncState"))

        // Scoped so the container is released before the metadata is read again.
        do {
            _ = try BaselineStore.makeContainer(
                cloudStoreURL: fixture.cloudStoreURL,
                localStoreURL: fixture.localStoreURL,
                cloudKitDatabase: .none
            )
        }

        XCTAssertEqual(try versionHashes(at: fixture.cloudStoreURL), cloudBefore)
        XCTAssertEqual(try versionHashes(at: fixture.localStoreURL), localBefore)
    }

    /// Entity name -> version hash, read from the store's metadata without opening it.
    private func versionHashes(at url: URL) throws -> [String: Data] {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: url)
        let hashes = try XCTUnwrap(
            metadata[NSStoreModelVersionHashesKey] as? [String: Data],
            "No version hashes in \(url.lastPathComponent) metadata: \(metadata.keys.sorted())"
        )
        XCTAssertFalse(hashes.isEmpty, "\(url.lastPathComponent) has no entity version hashes")
        return hashes
    }
}
