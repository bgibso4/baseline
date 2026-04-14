import XCTest
import SwiftData
@testable import Baseline

final class ScanTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([Scan.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makePayload(
        weightKg: Double = 80.0,
        skeletalMuscleMassKg: Double = 35.0,
        bodyFatMassKg: Double = 15.0,
        bodyFatPct: Double = 18.5,
        totalBodyWaterL: Double = 45.0,
        bmi: Double = 24.5,
        basalMetabolicRate: Double = 1800
    ) -> InBodyPayload {
        InBodyPayload(
            weightKg: weightKg,
            skeletalMuscleMassKg: skeletalMuscleMassKg,
            bodyFatMassKg: bodyFatMassKg,
            bodyFatPct: bodyFatPct,
            totalBodyWaterL: totalBodyWaterL,
            bmi: bmi,
            basalMetabolicRate: basalMetabolicRate
        )
    }

    private func encodePayload(_ payload: InBodyPayload) -> Data {
        try! JSONEncoder().encode(payload)
    }

    // MARK: - Scan Creation

    func testCreateScan() {
        let payload = makePayload()
        let data = encodePayload(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)

        context.insert(scan)
        try! context.save()

        let descriptor = FetchDescriptor<Scan>()
        let results = try! context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, ScanType.inBody.rawValue)
        XCTAssertEqual(results.first?.source, ScanSource.manual.rawValue)
    }

    func testScanTypeComputedProperty() {
        let scan = Scan(date: Date(), type: .inBody, source: .ocr, payload: encodePayload(makePayload()))
        XCTAssertEqual(scan.scanType, .inBody)
        XCTAssertEqual(scan.scanSource, .ocr)
    }

    func testDateNormalizedToStartOfDay() {
        let afternoon = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let scan = Scan(date: afternoon, type: .inBody, source: .manual, payload: encodePayload(makePayload()))
        XCTAssertEqual(scan.date, Calendar.current.startOfDay(for: afternoon))
    }

    // MARK: - Payload Decode

    func testDecodeInBodyPayload() throws {
        let payload = makePayload(weightKg: 82.5, bodyFatPct: 20.0)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: encodePayload(payload))

        let content = try scan.decoded()
        guard case .inBody(let decoded) = content else {
            XCTFail("Expected .inBody case")
            return
        }
        XCTAssertEqual(decoded.weightKg, 82.5)
        XCTAssertEqual(decoded.bodyFatPct, 20.0)
        XCTAssertEqual(decoded, payload)
    }

    func testDecodeRoundTrip() throws {
        let payload = InBodyPayload(
            weightKg: 80.0,
            skeletalMuscleMassKg: 35.0,
            bodyFatMassKg: 15.0,
            bodyFatPct: 18.5,
            totalBodyWaterL: 45.0,
            bmi: 24.5,
            basalMetabolicRate: 1800,
            intracellularWaterL: 28.0,
            extracellularWaterL: 17.0,
            dryLeanMassKg: 18.0,
            leanBodyMassKg: 65.0,
            inBodyScore: 82,
            rightArmLeanKg: 3.5,
            leftArmLeanKg: 3.4,
            trunkLeanKg: 28.0,
            rightLegLeanKg: 10.0,
            leftLegLeanKg: 9.8,
            rightArmFatKg: 0.8,
            leftArmFatKg: 0.9,
            trunkFatKg: 8.0,
            rightLegFatKg: 2.5,
            leftLegFatKg: 2.6
        )
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .imported, payload: data)

        let content = try scan.decoded()
        guard case .inBody(let decoded) = content else {
            XCTFail("Expected .inBody case")
            return
        }
        XCTAssertEqual(decoded, payload)
    }

    func testDecodeUnknownTypeThrows() {
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: Data())
        // Manually set an unknown type to simulate future/corrupt data
        scan.type = "unknown"
        XCTAssertThrowsError(try scan.decoded()) { error in
            guard case ScanDecodingError.unknownType(let typeName) = error else {
                XCTFail("Expected ScanDecodingError.unknownType, got \(error)")
                return
            }
            XCTAssertEqual(typeName, "unknown")
        }
    }

    // MARK: - New Fields

    func testInBodyPayload_NewFieldsDefaultToNil() {
        let payload = InBodyPayload(
            weightKg: 90.0,
            skeletalMuscleMassKg: 40.0,
            bodyFatMassKg: 15.0,
            bodyFatPct: 16.7,
            totalBodyWaterL: 55.0,
            bmi: 25.0,
            basalMetabolicRate: 1850
        )
        XCTAssertNil(payload.ecwTbwRatio)
        XCTAssertNil(payload.skeletalMuscleIndex)
        XCTAssertNil(payload.visceralFatLevel)
        XCTAssertNil(payload.rightArmLeanPct)
        XCTAssertNil(payload.rightArmFatPct)
        XCTAssertNil(payload.trunkLeanPct)
        XCTAssertNil(payload.trunkFatPct)
    }

    func testInBodyPayload_NewFieldsRoundTrip() throws {
        var payload = InBodyPayload(
            weightKg: 90.0, skeletalMuscleMassKg: 40.0, bodyFatMassKg: 15.0,
            bodyFatPct: 16.7, totalBodyWaterL: 55.0, bmi: 25.0, basalMetabolicRate: 1850
        )
        payload.ecwTbwRatio = 0.380
        payload.skeletalMuscleIndex = 10.4
        payload.visceralFatLevel = 3
        payload.rightArmLeanPct = 112.4
        payload.trunkFatPct = 94.5

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(InBodyPayload.self, from: data)
        XCTAssertEqual(decoded.ecwTbwRatio, 0.380)
        XCTAssertEqual(decoded.skeletalMuscleIndex, 10.4)
        XCTAssertEqual(decoded.visceralFatLevel, 3)
        XCTAssertEqual(decoded.rightArmLeanPct, 112.4)
        XCTAssertEqual(decoded.trunkFatPct, 94.5)
    }

    func testInBodyPayload_BackwardsCompatible() throws {
        let oldJSON = """
        {"weightKg":90,"skeletalMuscleMassKg":40,"bodyFatMassKg":15,"bodyFatPct":16.7,"totalBodyWaterL":55,"bmi":25,"basalMetabolicRate":1850}
        """
        let decoded = try JSONDecoder().decode(InBodyPayload.self, from: oldJSON.data(using: .utf8)!)
        XCTAssertEqual(decoded.weightKg, 90)
        XCTAssertNil(decoded.ecwTbwRatio)
        XCTAssertNil(decoded.skeletalMuscleIndex)
        XCTAssertNil(decoded.rightArmLeanPct)
    }

    // MARK: - CloudKit Encryption

    func testHealthFieldsAllowCloudEncryption() throws {
        let schema = Schema([Scan.self])
        let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Scan" }))

        let payloadAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "payloadData" }))
        XCTAssertTrue(payloadAttr.options.contains(.allowsCloudEncryption), "payloadData must allow cloud encryption")

        let notesAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "notes" }))
        XCTAssertTrue(notesAttr.options.contains(.allowsCloudEncryption), "notes must allow cloud encryption")
    }

    func testStructuralFieldsNotEncrypted() throws {
        let schema = Schema([Scan.self])
        let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Scan" }))

        let dateAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "date" }))
        XCTAssertFalse(dateAttr.options.contains(.allowsCloudEncryption), "date must not be encrypted")

        let typeAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "type" }))
        XCTAssertFalse(typeAttr.options.contains(.allowsCloudEncryption), "type must not be encrypted")
    }

    // MARK: - Enums

    func testScanTypeCases() {
        XCTAssertEqual(ScanType.allCases.count, 1)
        XCTAssertEqual(ScanType.inBody.rawValue, "inBody")
    }

    func testScanSourceCases() {
        XCTAssertEqual(ScanSource.allCases.count, 3)
        XCTAssertEqual(ScanSource.manual.rawValue, "manual")
        XCTAssertEqual(ScanSource.ocr.rawValue, "ocr")
        XCTAssertEqual(ScanSource.imported.rawValue, "imported")
    }
}
