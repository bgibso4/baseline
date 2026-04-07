import Testing
import Foundation
import SwiftData
@testable import Baseline

@Suite("OutboundMirror Tests")
struct OutboundMirrorTests {

    // MARK: - NoOp

    @Test("NoOpOutboundMirror.mirror does nothing without error")
    func testNoOpDoesNothing() async {
        let mirror = NoOpOutboundMirror()
        let entry = WeightEntry(weight: 185.0, unit: "lb")
        await mirror.mirror(entry)
        // No crash, no side effects — that's the test.
    }

    @Test("NoOpOutboundMirror.reconcile does nothing without error")
    func testNoOpReconcileDoesNothing() async throws {
        let mirror = NoOpOutboundMirror()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema([WeightEntry.self, Scan.self, Measurement.self, SyncState.self]),
            configurations: config
        )
        let context = ModelContext(container)
        await mirror.reconcile(context: context)
    }

    // MARK: - MirrorableRecord Payloads

    @Test("WeightEntry produces correct mirror payload")
    func testWeightEntryMirrorPayload() {
        let entry = WeightEntry(weight: 185.5, unit: "lb", date: Date(), notes: "Morning")
        let payload = entry.toMirrorPayload()

        #expect(payload["id"] as? String == entry.id.uuidString)
        #expect(payload["weight"] as? Double == 185.5)
        #expect(payload["unit"] as? String == "lb")
        #expect(payload["notes"] as? String == "Morning")
        #expect(payload["date"] != nil)
        #expect(payload["created_at"] != nil)
        #expect(payload["updated_at"] != nil)
    }

    @Test("WeightEntry payload omits notes when nil")
    func testWeightEntryPayloadOmitsNilNotes() {
        let entry = WeightEntry(weight: 80.0, unit: "kg")
        let payload = entry.toMirrorPayload()

        #expect(payload["notes"] == nil)
    }

    @Test("Scan produces correct mirror payload")
    func testScanMirrorPayload() throws {
        let inBodyPayload = InBodyPayload(
            weightKg: 84.0,
            skeletalMuscleMassKg: 38.5,
            bodyFatMassKg: 12.0,
            bodyFatPct: 14.3,
            totalBodyWaterL: 52.0,
            bmi: 24.5,
            basalMetabolicRate: 1850
        )
        let data = try JSONEncoder().encode(inBodyPayload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data, notes: "Post-workout")
        let payload = scan.toMirrorPayload()

        #expect(payload["id"] as? String == scan.id.uuidString)
        #expect(payload["type"] as? String == "inBody")
        #expect(payload["source"] as? String == "manual")
        #expect(payload["notes"] as? String == "Post-workout")
        #expect(payload["payload_data"] as? String == data.base64EncodedString())
    }

    @Test("Measurement produces correct mirror payload")
    func testMeasurementMirrorPayload() {
        let measurement = Measurement(date: Date(), type: .waist, valueCm: 82.5, notes: nil)
        let payload = measurement.toMirrorPayload()

        #expect(payload["id"] as? String == measurement.id.uuidString)
        #expect(payload["type"] as? String == "waist")
        #expect(payload["value_cm"] as? Double == 82.5)
        #expect(payload["notes"] == nil)
    }

    // MARK: - SyncState

    @Test("SyncState returns empty timestamp for unknown table")
    func testGetLastSyncReturnsEmpty() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema([SyncState.self]),
            configurations: config
        )
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.tableName == "weight_entries" }
        )
        descriptor.fetchLimit = 1
        let result = try context.fetch(descriptor)

        #expect(result.isEmpty)
    }

    @Test("SyncState stores and retrieves last sync timestamp")
    func testSetAndGetLastSync() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema([SyncState.self]),
            configurations: config
        )
        let context = ModelContext(container)

        let state = SyncState(tableName: "weight_entries", lastSyncTimestamp: "2026-04-05T12:00:00Z")
        context.insert(state)
        try context.save()

        var descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.tableName == "weight_entries" }
        )
        descriptor.fetchLimit = 1
        let fetched = try context.fetch(descriptor).first

        #expect(fetched != nil)
        #expect(fetched?.lastSyncTimestamp == "2026-04-05T12:00:00Z")
    }
}
