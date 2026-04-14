import XCTest
import SwiftData
@testable import Baseline

private typealias Measurement = Baseline.Measurement

final class MeasurementTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([Measurement.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testCreateMeasurement() {
        let m = Measurement(date: Date(), type: .waist, valueCm: 85.0)
        context.insert(m)
        try! context.save()

        let descriptor = FetchDescriptor<Measurement>()
        let results = try! context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.valueCm, 85.0)
        XCTAssertEqual(results.first?.type, MeasurementType.waist.rawValue)
    }

    func testMeasurementTypeComputedProperty() {
        let m = Measurement(date: Date(), type: .chest, valueCm: 100.0)
        XCTAssertEqual(m.measurementType, .chest)
    }

    func testMeasurementWithNotes() {
        let m = Measurement(date: Date(), type: .neck, valueCm: 40.0, notes: "Morning measurement")
        XCTAssertEqual(m.notes, "Morning measurement")
    }

    func testDateNormalizedToStartOfDay() {
        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let m = Measurement(date: afternoon, type: .hips, valueCm: 95.0)
        XCTAssertEqual(m.date, Calendar.current.startOfDay(for: afternoon))
    }

    func testAllMeasurementTypesHaveDisplayName() {
        for type in MeasurementType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type) should have a non-empty displayName")
        }
    }

    func testMeasurementTypeDefaultUnitLabel() {
        for type in MeasurementType.allCases {
            XCTAssertEqual(type.defaultUnitLabel, "cm")
        }
    }

    // MARK: - CloudKit Encryption

    func testHealthFieldsAllowCloudEncryption() throws {
        let schema = Schema([Measurement.self])
        let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Measurement" }))

        let valueAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "valueCm" }))
        XCTAssertTrue(valueAttr.options.contains(.allowsCloudEncryption), "valueCm must allow cloud encryption")

        let notesAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "notes" }))
        XCTAssertTrue(notesAttr.options.contains(.allowsCloudEncryption), "notes must allow cloud encryption")
    }

    func testStructuralFieldsNotEncrypted() throws {
        let schema = Schema([Measurement.self])
        let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Measurement" }))

        let dateAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "date" }))
        XCTAssertFalse(dateAttr.options.contains(.allowsCloudEncryption))

        let typeAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "type" }))
        XCTAssertFalse(typeAttr.options.contains(.allowsCloudEncryption))
    }

    func testMeasurementTypeCaseCount() {
        XCTAssertEqual(MeasurementType.allCases.count, 10)
    }
}
