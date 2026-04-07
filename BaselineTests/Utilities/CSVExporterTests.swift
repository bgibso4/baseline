import XCTest
import SwiftData
@testable import Baseline

private typealias Measurement = Baseline.Measurement

final class CSVExporterTests: XCTestCase {
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

    // MARK: - Weights

    func testExportWeightEntries() {
        let entry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        context.insert(entry)
        try! context.save()

        let csv = CSVExporter.exportWeights(context: context)
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("date,weight,unit,notes"))
        XCTAssertTrue(lines[1].contains("197.4"))
        XCTAssertTrue(lines[1].contains("lb"))
    }

    // MARK: - Measurements

    func testExportMeasurements() {
        let m = Measurement(date: Date(), type: .waist, valueCm: 85.0)
        context.insert(m)
        try! context.save()

        let csv = CSVExporter.exportMeasurements(context: context)
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("waist"))
        XCTAssertTrue(lines[1].contains("85.0"))
    }

    // MARK: - Scans

    func testExportScans() {
        let payload = InBodyPayload(
            weightKg: 89.5,
            skeletalMuscleMassKg: 38.2,
            bodyFatMassKg: 15.1,
            bodyFatPct: 16.9,
            totalBodyWaterL: 54.3,
            bmi: 25.8,
            basalMetabolicRate: 1850
        )
        let data = try! JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)
        context.insert(scan)
        try! context.save()

        let csv = CSVExporter.exportScans(context: context)
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("89.5"))
        XCTAssertTrue(lines[1].contains("16.9"))
        XCTAssertTrue(lines[1].contains("1850"))
    }

    // MARK: - Empty

    func testExportEmptyReturnsHeaderOnly() {
        let weightsCSV = CSVExporter.exportWeights(context: context)
        XCTAssertEqual(weightsCSV, "date,weight,unit,notes")

        let measurementsCSV = CSVExporter.exportMeasurements(context: context)
        XCTAssertEqual(measurementsCSV, "date,type,valueCm,notes")

        let scansCSV = CSVExporter.exportScans(context: context)
        XCTAssertEqual(scansCSV, "date,type,source,weightKg,skeletalMuscleMassKg,bodyFatMassKg,bodyFatPct,totalBodyWaterL,bmi,basalMetabolicRate")
    }
}
