import CryptoKit
import XCTest

/// Decodable mirror of `Fixtures/SchemaV1/expected.json`. Dates are
/// `timeIntervalSinceReferenceDate`; payloads are base64; the photo is a SHA-256 hex digest.
struct SchemaV1Expected: Decodable {
    struct Weight: Decodable {
        let id: String
        let weight: Double
        let unit: String
        let date: Double
        let notes: String?
        let photoSHA256: String?
        let createdAt: Double
        let updatedAt: Double
    }

    struct Scan: Decodable {
        let id: String
        let date: Double
        let type: String
        let source: String
        let notes: String?
        let payloadBase64: String
        let createdAt: Double
        let updatedAt: Double
    }

    struct Measurement: Decodable {
        let id: String
        let date: Double
        let type: String
        let valueCm: Double
        let notes: String?
        let createdAt: Double
        let updatedAt: Double
    }

    struct Goal: Decodable {
        let id: String
        let metric: String
        let targetValue: Double
        let targetDate: Double?
        let startValue: Double
        let startDate: Double
        let status: String
        let completedDate: Double?
        let createdAt: Double
    }

    struct SyncState: Decodable {
        let tableName: String
        let lastSyncTimestamp: String
    }

    let localStoreFileName: String
    let weights: [Weight]
    let scans: [Scan]
    let measurements: [Measurement]
    let goals: [Goal]
    let syncStates: [SyncState]
}

/// A throwaway copy of the SchemaV1 golden fixture that a test can open and mutate freely.
struct FixtureStore {
    let directory: URL
    var cloudStoreURL: URL { directory.appendingPathComponent("Baseline.store") }
    var localStoreURL: URL { directory.appendingPathComponent("BaselineLocal.store") }

    private final class BundleToken {}
    private static var fixtureURL: URL {
        get throws {
            try XCTUnwrap(
                Bundle(for: BundleToken.self).url(forResource: "SchemaV1", withExtension: nil),
                "SchemaV1 fixture folder is missing from the test bundle"
            )
        }
    }

    /// Copies the fixture into a fresh temp directory and restores the hidden
    /// `.Baseline_SUPPORT` external-storage directory (stored undotted in the bundle).
    static func copyFixture() throws -> FixtureStore {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("SchemaV1Fixture-\(UUID().uuidString)", isDirectory: true)
        try fileManager.copyItem(at: try fixtureURL, to: directory)
        try fileManager.moveItem(
            at: directory.appendingPathComponent("Baseline_SUPPORT"),
            to: directory.appendingPathComponent(".Baseline_SUPPORT")
        )
        return FixtureStore(directory: directory)
    }

    static func expected() throws -> SchemaV1Expected {
        let data = try Data(contentsOf: try fixtureURL.appendingPathComponent("expected.json"))
        return try JSONDecoder().decode(SchemaV1Expected.self, from: data)
    }

    /// Relative path -> SHA-256 hex for every file under `directory`, hidden ones included.
    func fileHashes() throws -> [String: String] {
        let fileManager = FileManager.default
        guard let walker = fileManager.enumerator(atPath: directory.path) else { return [:] }
        var hashes: [String: String] = [:]
        for case let relative as String in walker {
            let url = directory.appendingPathComponent(relative)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                continue
            }
            let digest = SHA256.hash(data: try Data(contentsOf: url))
            hashes[relative] = digest.map { String(format: "%02x", $0) }.joined()
        }
        return hashes
    }
}
