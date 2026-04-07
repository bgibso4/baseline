import XCTest
import SwiftData
@testable import Baseline

private typealias Measurement = Baseline.Measurement

final class BodyViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, Scan.self, Measurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Measurements

    func testLatestMeasurementsByType() {
        let older = Measurement(date: Date().addingTimeInterval(-86400 * 2), type: .waist, valueCm: 80.0)
        let newer = Measurement(date: Date().addingTimeInterval(-86400), type: .waist, valueCm: 78.5)
        context.insert(older)
        context.insert(newer)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.refresh()

        let waistResults = vm.latestMeasurements.filter { $0.measurementType == .waist }
        XCTAssertEqual(waistResults.count, 1, "Should deduplicate by type, keeping only newest")
        XCTAssertEqual(waistResults.first?.valueCm, 78.5)
    }

    func testRecentScansSortedNewest() {
        let payload = try! JSONEncoder().encode(makePayload())
        let scan1 = Scan(date: Date().addingTimeInterval(-86400 * 3), type: .inBody, source: .manual, payload: payload)
        let scan2 = Scan(date: Date().addingTimeInterval(-86400 * 1), type: .inBody, source: .manual, payload: payload)
        let scan3 = Scan(date: Date().addingTimeInterval(-86400 * 2), type: .inBody, source: .manual, payload: payload)
        context.insert(scan1)
        context.insert(scan2)
        context.insert(scan3)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.refresh()

        XCTAssertEqual(vm.recentScans.count, 3)
        XCTAssertTrue(vm.recentScans[0].date >= vm.recentScans[1].date)
        XCTAssertTrue(vm.recentScans[1].date >= vm.recentScans[2].date)
    }

    func testSaveMeasurement() {
        let vm = BodyViewModel(modelContext: context)
        vm.saveMeasurement(type: .waist, valueCm: 82.0, notes: "Morning")

        let descriptor = FetchDescriptor<Measurement>()
        let results = try! context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.valueCm, 82.0)
        XCTAssertEqual(results.first?.notes, "Morning")
    }

    func testSaveScanEncodesPayload() {
        let vm = BodyViewModel(modelContext: context)
        let payload = makePayload(weightKg: 90.0, bodyFatPct: 18.5)
        vm.saveScan(type: .inBody, source: .manual, payload: payload, notes: nil)

        let descriptor = FetchDescriptor<Scan>()
        let scans = try! context.fetch(descriptor)
        XCTAssertEqual(scans.count, 1)

        let decoded = try! scans.first!.decoded()
        if case .inBody(let p) = decoded {
            XCTAssertEqual(p.weightKg, 90.0)
            XCTAssertEqual(p.bodyFatPct, 18.5)
        } else {
            XCTFail("Expected inBody payload")
        }
    }

    func testDeleteMeasurement() {
        let vm = BodyViewModel(modelContext: context)
        vm.saveMeasurement(type: .hips, valueCm: 95.0)

        let descriptor = FetchDescriptor<Measurement>()
        let saved = try! context.fetch(descriptor)
        XCTAssertEqual(saved.count, 1)

        vm.deleteMeasurement(saved.first!)

        let remaining = try! context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func testDeleteScan() {
        let vm = BodyViewModel(modelContext: context)
        vm.saveScan(type: .inBody, source: .ocr, payload: makePayload())

        let descriptor = FetchDescriptor<Scan>()
        let saved = try! context.fetch(descriptor)
        XCTAssertEqual(saved.count, 1)

        vm.deleteScan(saved.first!)

        let remaining = try! context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func testLatestValueConvenience() {
        let m = Measurement(date: Date(), type: .waist, valueCm: 79.0)
        context.insert(m)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.refresh()

        let result = vm.latestValue(for: .waist)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.valueCm, 79.0)
    }

    func testDecodedPayloadConvenience() {
        let payload = makePayload(weightKg: 85.0)
        let data = try! JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .imported, payload: data)
        context.insert(scan)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.refresh()

        let content = vm.decodedPayload(for: vm.recentScans.first!)
        XCTAssertNotNil(content)
        if case .inBody(let p) = content {
            XCTAssertEqual(p.weightKg, 85.0)
        } else {
            XCTFail("Expected inBody content")
        }
    }

    // MARK: - Helpers

    private func makePayload(
        weightKg: Double = 80.0,
        bodyFatPct: Double = 20.0
    ) -> InBodyPayload {
        InBodyPayload(
            weightKg: weightKg,
            skeletalMuscleMassKg: 35.0,
            bodyFatMassKg: weightKg * bodyFatPct / 100.0,
            bodyFatPct: bodyFatPct,
            totalBodyWaterL: 40.0,
            bmi: 25.0,
            basalMetabolicRate: 1800
        )
    }
}
