import CryptoKit
import SwiftData
import XCTest
@testable import Baseline

/// Asserts a store holds exactly the records recorded in the SchemaV1 fixture's `expected.json`.
extension XCTestCase {
    fileprivate func date(_ value: Double) -> Date { Date(timeIntervalSinceReferenceDate: value) }

    fileprivate func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func assertMatchesExpected(_ context: ModelContext, _ expected: SchemaV1Expected) throws {
        let weights = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.id)]))
        let expectedWeights = expected.weights.sorted { $0.id < $1.id }
        XCTAssertEqual(weights.count, expectedWeights.count)
        for (actual, want) in zip(weights, expectedWeights) {
            XCTAssertEqual(actual.id.uuidString, want.id)
            XCTAssertEqual(actual.weight, want.weight)
            XCTAssertEqual(actual.unit, want.unit)
            XCTAssertEqual(actual.date, date(want.date))
            XCTAssertEqual(actual.notes, want.notes)
            XCTAssertEqual(actual.photoData.map(sha256Hex), want.photoSHA256)
            XCTAssertEqual(actual.createdAt, date(want.createdAt))
            XCTAssertEqual(actual.updatedAt, date(want.updatedAt))
        }

        let scans = try context.fetch(FetchDescriptor<Scan>(sortBy: [SortDescriptor(\.id)]))
        let expectedScans = expected.scans.sorted { $0.id < $1.id }
        XCTAssertEqual(scans.count, expectedScans.count)
        for (actual, want) in zip(scans, expectedScans) {
            XCTAssertEqual(actual.id.uuidString, want.id)
            XCTAssertEqual(actual.date, date(want.date))
            XCTAssertEqual(actual.type, want.type)
            XCTAssertEqual(actual.source, want.source)
            XCTAssertEqual(actual.notes, want.notes)
            XCTAssertEqual(actual.payloadData, Data(base64Encoded: want.payloadBase64))
            XCTAssertEqual(actual.createdAt, date(want.createdAt))
            XCTAssertEqual(actual.updatedAt, date(want.updatedAt))
            XCTAssertNoThrow(try actual.decoded())
        }

        let measurements = try context.fetch(FetchDescriptor<Baseline.Measurement>(sortBy: [SortDescriptor(\.id)]))
        let expectedMeasurements = expected.measurements.sorted { $0.id < $1.id }
        XCTAssertEqual(measurements.count, expectedMeasurements.count)
        for (actual, want) in zip(measurements, expectedMeasurements) {
            XCTAssertEqual(actual.id.uuidString, want.id)
            XCTAssertEqual(actual.date, date(want.date))
            XCTAssertEqual(actual.type, want.type)
            XCTAssertEqual(actual.valueCm, want.valueCm)
            XCTAssertEqual(actual.notes, want.notes)
            XCTAssertEqual(actual.createdAt, date(want.createdAt))
            XCTAssertEqual(actual.updatedAt, date(want.updatedAt))
        }

        let goals = try context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.id)]))
        let expectedGoals = expected.goals.sorted { $0.id < $1.id }
        XCTAssertEqual(goals.count, expectedGoals.count)
        for (actual, want) in zip(goals, expectedGoals) {
            XCTAssertEqual(actual.id.uuidString, want.id)
            XCTAssertEqual(actual.metric, want.metric)
            XCTAssertEqual(actual.targetValue, want.targetValue)
            XCTAssertEqual(actual.targetDate, want.targetDate.map(date))
            XCTAssertEqual(actual.startValue, want.startValue)
            XCTAssertEqual(actual.startDate, date(want.startDate))
            XCTAssertEqual(actual.status.rawValue, want.status)
            XCTAssertEqual(actual.completedDate, want.completedDate.map(date))
            XCTAssertEqual(actual.createdAt, date(want.createdAt))
        }

        let syncStates = try context.fetch(FetchDescriptor<SyncState>(sortBy: [SortDescriptor(\.tableName)]))
        let expectedSync = expected.syncStates.sorted { $0.tableName < $1.tableName }
        XCTAssertEqual(syncStates.count, expectedSync.count)
        for (actual, want) in zip(syncStates, expectedSync) {
            XCTAssertEqual(actual.tableName, want.tableName)
            XCTAssertEqual(actual.lastSyncTimestamp, want.lastSyncTimestamp)
        }
    }
}
