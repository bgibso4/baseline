import XCTest
import SwiftData
@testable import Baseline

final class BodyMeasurementTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([BodyMeasurement.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testCreateManualMeasurement() {
        let m = BodyMeasurement(
            date: Date(),
            type: .waist,
            value: 33.5,
            unit: "in",
            source: .manual
        )
        context.insert(m)
        try! context.save()

        let descriptor = FetchDescriptor<BodyMeasurement>()
        let results = try! context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, MeasurementType.waist.rawValue)
        XCTAssertEqual(results.first?.source, MeasurementSource.manual.rawValue)
    }

    func testCreateInBodyMeasurement() {
        let m = BodyMeasurement(
            date: Date(),
            type: .bodyFatPercentage,
            value: 18.5,
            unit: "%",
            source: .inbody
        )
        XCTAssertEqual(m.source, MeasurementSource.inbody.rawValue)
    }

    func testMeasurementTypeCoversExpectedTypes() {
        let expectedTypes: [MeasurementType] = [
            .waist, .neck, .chest, .rightArm, .leftArm,
            .rightThigh, .leftThigh, .hips,
            .bodyFatPercentage, .skeletalMuscleMass, .leanBodyMass
        ]
        for type in expectedTypes {
            XCTAssertFalse(type.rawValue.isEmpty, "\(type) should have a non-empty rawValue")
        }
    }

    func testMeasurementTypeDisplayName() {
        XCTAssertEqual(MeasurementType.waist.displayName, "Waist")
        XCTAssertEqual(MeasurementType.rightArm.displayName, "Right Arm")
        XCTAssertEqual(MeasurementType.bodyFatPercentage.displayName, "Body Fat %")
    }

    func testCustomMeasurementType() {
        XCTAssertEqual(MeasurementType.custom.rawValue, "custom")
        XCTAssertEqual(MeasurementType.custom.displayName, "Custom")
    }
}
