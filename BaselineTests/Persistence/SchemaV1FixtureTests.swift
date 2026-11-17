import SwiftData
import XCTest
@testable import Baseline

/// Opens real on-disk stores written by the app at f66afa8 and asserts every record survives.
final class SchemaV1FixtureTests: XCTestCase {
    func testF66afa8StoreOpensWithEveryRecordIntact() throws {
        let fixture = try FixtureStore.copyFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let expected = try FixtureStore.expected()

        do {
            let container = try makeContainer(fixture)
            try assertMatchesExpected(ModelContext(container), expected)
        }
        // Everything above is released: reopen cold from the same files.
        let reopened = try makeContainer(fixture)
        try assertMatchesExpected(ModelContext(reopened), expected)
    }

    func testLocalStoreURLMatchesF66afa8() throws {
        let expected = try FixtureStore.expected()
        XCTAssertEqual(BaselineStore.localStoreURL.lastPathComponent, expected.localStoreFileName)
    }

    func testCloudStoreURLIsAppGroupBaselineStore() throws {
        let group = try XCTUnwrap(
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.cadre.baseline")
        )
        XCTAssertEqual(BaselineStore.cloudStoreURL.lastPathComponent, "Baseline.store")
        XCTAssertTrue(BaselineStore.cloudStoreURL.path.contains(group.path))
    }

    // MARK: - Helpers

    private func makeContainer(_ fixture: FixtureStore) throws -> ModelContainer {
        try BaselineStore.makeContainer(
            cloudStoreURL: fixture.cloudStoreURL,
            localStoreURL: fixture.localStoreURL,
            cloudKitDatabase: .none
        )
    }
}
