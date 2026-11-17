import SwiftData
import XCTest
@testable import Baseline

/// A store SwiftData cannot open must be left exactly as it was: no wipe, no partial migration.
final class IncompatibleStoreTests: XCTestCase {
    func testOpeningWithIncompatibleSchemaThrowsAndLeavesFilesUnchanged() throws {
        let fixture = try FixtureStore.copyFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let expected = try FixtureStore.expected()
        let before = try fixture.fileHashes()
        XCTAssertFalse(before.isEmpty)
        XCTAssertNotNil(before["Baseline.store"], "Baseline.store missing from hashed files: \(before.keys.sorted())")

        // Scoped so nothing holds the store open when the files are hashed again.
        do {
            XCTAssertThrowsError(
                try ModelContainer(
                    for: Schema(versionedSchema: IncompatibleSchema.self),
                    migrationPlan: IncompatibleOnlyPlan.self,
                    configurations: [
                        ModelConfiguration("Baseline", url: fixture.cloudStoreURL, cloudKitDatabase: .none)
                    ]
                )
            )
        }

        // SQLite creates the -wal/-shm sidecars on open; the data files themselves must be untouched.
        let after = try fixture.fileHashes()
        XCTAssertEqual(after.filter { before.keys.contains($0.key) }, before)
        XCTAssertTrue(
            Set(after.keys).subtracting(before.keys).isSubset(of: ["Baseline.store-wal", "Baseline.store-shm"]),
            "Unexpected new files: \(Set(after.keys).subtracting(before.keys).sorted())"
        )
        let walURL = fixture.directory.appendingPathComponent("Baseline.store-wal")
        if FileManager.default.fileExists(atPath: walURL.path) {
            let walSize = try FileManager.default.attributesOfItem(atPath: walURL.path)[.size] as? Int
            XCTAssertEqual(walSize, 0, "WAL must hold no frames after a failed open")
        }

        // The untouched store still opens under the production plan with every record intact.
        let container = try BaselineStore.makeContainer(
            cloudStoreURL: fixture.cloudStoreURL,
            localStoreURL: fixture.localStoreURL,
            cloudKitDatabase: .none
        )
        try assertMatchesExpected(ModelContext(container), expected)
    }
}

/// Changes `WeightEntry.weight` from Double to String: not inferable, and no stage describes it.
private enum IncompatibleSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(9, 0, 0) }
    static var models: [any PersistentModel.Type] { [WeightEntry.self] }

    @Model
    final class WeightEntry {
        var weight: String = ""

        init(weight: String) {
            self.weight = weight
        }
    }
}

private enum IncompatibleOnlyPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [IncompatibleSchema.self] }
    static var stages: [MigrationStage] { [] }
}
