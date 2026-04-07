import XCTest
@testable import Baseline

final class InBodyOCRParserTests: XCTestCase {

    private let lbsToKg: Double = 0.45359237

    // MARK: - Weight Parsing (lb → kg)

    func testParseWeight() {
        let text = """
        Body Composition Analysis
        Weight: 197.4 lbs
        Skeletal Muscle Mass: 85.2 lbs
        Body Fat Mass: 35.6 lbs
        """
        let result = InBodyOCRParser.parse(text)
        let expectedKg = 197.4 * lbsToKg
        XCTAssertNotNil(result.weightKg)
        XCTAssertEqual(result.weightKg!, expectedKg, accuracy: 0.1)
    }

    // MARK: - Body Fat Percentage

    func testParseBodyFatPercentage() {
        let text = """
        Percent Body Fat
        18.5 %
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.bodyFatPct!, 18.5, accuracy: 0.1)
    }

    // MARK: - Skeletal Muscle Mass (lb → kg)

    func testParseSkeletalMuscleMass() {
        let text = """
        Skeletal Muscle Mass
        85.2 lbs
        """
        let result = InBodyOCRParser.parse(text)
        let expectedKg = 85.2 * lbsToKg
        XCTAssertNotNil(result.skeletalMuscleMassKg)
        XCTAssertEqual(result.skeletalMuscleMassKg!, expectedKg, accuracy: 0.1)
    }

    // MARK: - BMI and InBody Score

    func testParseBMI() {
        let text = """
        BMI: 25.3
        InBody Score: 78
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.bmi!, 25.3, accuracy: 0.1)
        XCTAssertEqual(result.inBodyScore!, 78, accuracy: 0.1)
    }

    // MARK: - Segmental Lean (lb → kg)

    func testParseSegmentalLean() {
        let text = """
        Segmental Lean Analysis
        Right Arm: 8.5 lbs
        Left Arm: 8.3 lbs
        Trunk: 52.1 lbs
        Right Leg: 20.4 lbs
        Left Leg: 20.2 lbs
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.rightArmLeanKg!, 8.5 * lbsToKg, accuracy: 0.1)
        XCTAssertEqual(result.leftArmLeanKg!, 8.3 * lbsToKg, accuracy: 0.1)
        XCTAssertEqual(result.trunkLeanKg!, 52.1 * lbsToKg, accuracy: 0.1)
        XCTAssertEqual(result.rightLegLeanKg!, 20.4 * lbsToKg, accuracy: 0.1)
        XCTAssertEqual(result.leftLegLeanKg!, 20.2 * lbsToKg, accuracy: 0.1)
    }

    // MARK: - Missing Fields

    func testParseReturnsNilForMissingFields() {
        let text = "Weight: 197.4 lbs"
        let result = InBodyOCRParser.parse(text)
        XCTAssertNotNil(result.weightKg)
        XCTAssertNil(result.bodyFatPct)
        XCTAssertNil(result.skeletalMuscleMassKg)
        XCTAssertNil(result.bmi)
    }

    // MARK: - Empty Text

    func testEmptyTextReturnsAllNil() {
        let result = InBodyOCRParser.parse("")
        XCTAssertNil(result.weightKg)
        XCTAssertNil(result.bodyFatPct)
        XCTAssertNil(result.skeletalMuscleMassKg)
        XCTAssertNil(result.bodyFatMassKg)
        XCTAssertNil(result.bmi)
        XCTAssertNil(result.totalBodyWaterL)
        XCTAssertNil(result.basalMetabolicRate)
        XCTAssertNil(result.inBodyScore)
    }

    // MARK: - toPayload() Success

    func testToPayloadSucceedsWithCoreFields() throws {
        var result = InBodyParseResult()
        result.weightKg = 89.5
        result.skeletalMuscleMassKg = 38.6
        result.bodyFatMassKg = 16.1
        result.bodyFatPct = 18.5
        result.totalBodyWaterL = 45.2
        result.bmi = 25.3
        result.basalMetabolicRate = 1850
        result.inBodyScore = 78

        let payload = try result.toPayload()
        XCTAssertEqual(payload.weightKg, 89.5, accuracy: 0.01)
        XCTAssertEqual(payload.skeletalMuscleMassKg, 38.6, accuracy: 0.01)
        XCTAssertEqual(payload.bodyFatMassKg, 16.1, accuracy: 0.01)
        XCTAssertEqual(payload.bodyFatPct, 18.5, accuracy: 0.01)
        XCTAssertEqual(payload.totalBodyWaterL, 45.2, accuracy: 0.01)
        XCTAssertEqual(payload.bmi, 25.3, accuracy: 0.01)
        XCTAssertEqual(payload.basalMetabolicRate, 1850, accuracy: 0.01)
        XCTAssertEqual(payload.inBodyScore, 78)
    }

    // MARK: - toPayload() Throws on Missing Core Fields

    func testToPayloadThrowsWithMissingCoreFields() {
        var result = InBodyParseResult()
        result.weightKg = 89.5
        // Missing all other core fields

        XCTAssertThrowsError(try result.toPayload()) { error in
            guard let conversionError = error as? InBodyParseResult.ConversionError else {
                XCTFail("Expected ConversionError")
                return
            }
            if case .missingRequiredFields(let fields) = conversionError {
                XCTAssertTrue(fields.contains("skeletalMuscleMassKg"))
                XCTAssertTrue(fields.contains("bodyFatMassKg"))
                XCTAssertTrue(fields.contains("bodyFatPct"))
                XCTAssertTrue(fields.contains("totalBodyWaterL"))
                XCTAssertTrue(fields.contains("bmi"))
                XCTAssertTrue(fields.contains("basalMetabolicRate"))
                XCTAssertFalse(fields.contains("weightKg")) // weight was provided
            }
        }
    }

    // MARK: - lb → kg Conversion Accuracy

    func testLbToKgConversion() {
        let text = """
        Weight: 200.0 lbs
        Skeletal Muscle Mass: 100.0 lbs
        Body Fat Mass: 40.0 lbs
        """
        let result = InBodyOCRParser.parse(text)

        // 200 lbs = 90.718474 kg
        XCTAssertEqual(result.weightKg!, 200.0 * lbsToKg, accuracy: 0.001)
        // 100 lbs = 45.359237 kg
        XCTAssertEqual(result.skeletalMuscleMassKg!, 100.0 * lbsToKg, accuracy: 0.001)
        // 40 lbs = 18.1436948 kg
        XCTAssertEqual(result.bodyFatMassKg!, 40.0 * lbsToKg, accuracy: 0.001)
    }
}
