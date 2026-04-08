import XCTest
@testable import Baseline

final class InBody570RegionParsersTests: XCTestCase {

    private let lbsToKg: Double = 0.45359237

    // MARK: - Unit Detection

    func testDetectUnit_Lbs() {
        let text = "Weight 197.4 lbs"
        XCTAssertEqual(InBody570RegionParsers.detectUnit(from: text), .lbs)
    }

    func testDetectUnit_Kg() {
        let text = "Weight 89.5 kg"
        XCTAssertEqual(InBody570RegionParsers.detectUnit(from: text), .kg)
    }

    func testDetectUnit_Default() {
        let text = "Weight 197.4"
        XCTAssertEqual(InBody570RegionParsers.detectUnit(from: text), .lbs)
    }

    // MARK: - R1: Header

    func testParseHeader_ExtractsDate() {
        let text = "Male  01. 15. 2026 07:37"
        let result = InBody570RegionParsers.parseHeader(text)

        XCTAssertNotNil(result.scanDate)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result.scanDate!)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 37)
    }

    func testParseHeader_DateOnly() {
        let text = "Female  12. 25. 2025"
        let result = InBody570RegionParsers.parseHeader(text)

        XCTAssertNotNil(result.scanDate)
        let components = Calendar.current.dateComponents([.month, .day, .year], from: result.scanDate!)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 25)
        XCTAssertEqual(components.year, 2025)
    }

    func testParseHeader_NoDate() {
        let text = "InBody 570 Result"
        let result = InBody570RegionParsers.parseHeader(text)
        XCTAssertNil(result.scanDate)
    }

    // MARK: - R2: Body Composition Analysis

    func testParseBodyComposition_LbsUnit() {
        let text = """
        Intracellular Water  28.5
        Extracellular Water  17.8
        Total Body Water  46.3
        Dry Lean Mass  32.1
        Lean Body Mass  155.2
        Body Fat Mass  42.2
        """
        let result = InBody570RegionParsers.parseBodyComposition(text, unit: .lbs)

        // Water values stored as-is (liters, no conversion)
        XCTAssertEqual(result.intracellularWaterL!, 28.5, accuracy: 0.01)
        XCTAssertEqual(result.extracellularWaterL!, 17.8, accuracy: 0.01)
        XCTAssertEqual(result.totalBodyWaterL!, 46.3, accuracy: 0.01)

        // Mass values converted from lbs to kg
        XCTAssertEqual(result.dryLeanMassKg!, 32.1 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.leanBodyMassKg!, 155.2 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.bodyFatMassKg!, 42.2 * lbsToKg, accuracy: 0.01)
    }

    func testParseBodyComposition_KgUnit() {
        let text = """
        Intracellular Water  28.5
        Extracellular Water  17.8
        Total Body Water  46.3
        Dry Lean Mass  14.6
        Lean Body Mass  70.4
        Body Fat Mass  19.1
        """
        let result = InBody570RegionParsers.parseBodyComposition(text, unit: .kg)

        // Water — still no conversion
        XCTAssertEqual(result.intracellularWaterL!, 28.5, accuracy: 0.01)
        XCTAssertEqual(result.extracellularWaterL!, 17.8, accuracy: 0.01)
        XCTAssertEqual(result.totalBodyWaterL!, 46.3, accuracy: 0.01)

        // Mass — already kg, no conversion
        XCTAssertEqual(result.dryLeanMassKg!, 14.6, accuracy: 0.01)
        XCTAssertEqual(result.leanBodyMassKg!, 70.4, accuracy: 0.01)
        XCTAssertEqual(result.bodyFatMassKg!, 19.1, accuracy: 0.01)
    }

    // MARK: - R3: Muscle-Fat Analysis

    func testParseMuscleFat_ExtractsWeightAndSMM() {
        let text = """
        Weight  197.4
        Skeletal Muscle Mass  85.2
        Body Fat Mass  42.2
        """
        let result = InBody570RegionParsers.parseMuscleFat(text, unit: .lbs)

        XCTAssertEqual(result.weightKg!, 197.4 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.skeletalMuscleMassKg!, 85.2 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.bodyFatMassKg!, 42.2 * lbsToKg, accuracy: 0.01)
    }

    // MARK: - R4: Obesity Analysis

    func testParseObesity_ExtractsBMIAndPBF() {
        let text = """
        BMI  27.3
        PBF  21.4
        """
        let result = InBody570RegionParsers.parseObesity(text)

        XCTAssertEqual(result.bmi!, 27.3, accuracy: 0.01)
        XCTAssertEqual(result.bodyFatPct!, 21.4, accuracy: 0.01)
    }

    // MARK: - R5: Segmental Lean Analysis

    func testParseSegmentalLean_ExtractsMassAndPct() {
        let text = """
        Right Arm  8.22  105.3
        Left Arm  8.05  103.1
        Trunk  61.5  110.2
        Right Leg  23.1  108.7
        Left Leg  22.9  107.5
        """
        let result = InBody570RegionParsers.parseSegmentalLean(text, unit: .lbs)

        // Mass values converted from lbs to kg
        XCTAssertEqual(result.rightArmLeanKg!, 8.22 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.leftArmLeanKg!, 8.05 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.trunkLeanKg!, 61.5 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.rightLegLeanKg!, 23.1 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.leftLegLeanKg!, 22.9 * lbsToKg, accuracy: 0.01)

        // Sufficiency percentages (unitless)
        XCTAssertEqual(result.rightArmLeanPct!, 105.3, accuracy: 0.01)
        XCTAssertEqual(result.leftArmLeanPct!, 103.1, accuracy: 0.01)
        XCTAssertEqual(result.trunkLeanPct!, 110.2, accuracy: 0.01)
        XCTAssertEqual(result.rightLegLeanPct!, 108.7, accuracy: 0.01)
        XCTAssertEqual(result.leftLegLeanPct!, 107.5, accuracy: 0.01)
    }

    // MARK: - R6: ECW/TBW

    func testParseEcwTbw() {
        let text = "ECW/TBW  0.385"
        let result = InBody570RegionParsers.parseEcwTbw(text)
        XCTAssertEqual(result.ecwTbwRatio!, 0.385, accuracy: 0.001)
    }

    // MARK: - R7: Segmental Fat Analysis

    func testParseSegmentalFat_ExtractsMassAndPct() {
        let text = """
        Right Arm  2.1  95.0
        Left Arm  2.0  92.5
        Trunk  15.3  110.0
        Right Leg  4.5  100.0
        Left Leg  4.4  98.0
        """
        let result = InBody570RegionParsers.parseSegmentalFat(text, unit: .lbs)

        XCTAssertEqual(result.rightArmFatKg!, 2.1 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.leftArmFatKg!, 2.0 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.trunkFatKg!, 15.3 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.rightLegFatKg!, 4.5 * lbsToKg, accuracy: 0.01)
        XCTAssertEqual(result.leftLegFatKg!, 4.4 * lbsToKg, accuracy: 0.01)

        XCTAssertEqual(result.rightArmFatPct!, 95.0, accuracy: 0.01)
        XCTAssertEqual(result.leftArmFatPct!, 92.5, accuracy: 0.01)
        XCTAssertEqual(result.trunkFatPct!, 110.0, accuracy: 0.01)
        XCTAssertEqual(result.rightLegFatPct!, 100.0, accuracy: 0.01)
        XCTAssertEqual(result.leftLegFatPct!, 98.0, accuracy: 0.01)
    }

    // MARK: - R8: BMR

    func testParseBMR() {
        let text = "Basal Metabolic Rate  1856 kcal"
        let result = InBody570RegionParsers.parseBMR(text)
        XCTAssertEqual(result.basalMetabolicRate!, 1856, accuracy: 0.1)
    }

    // MARK: - R9: SMI

    func testParseSMI() {
        let text = "SMI  11.2 kg/m²"
        let result = InBody570RegionParsers.parseSMI(text)
        XCTAssertEqual(result.skeletalMuscleIndex!, 11.2, accuracy: 0.01)
    }

    // MARK: - R10: Visceral Fat

    func testParseVisceralFat() {
        let text = "Visceral Fat Level  8"
        let result = InBody570RegionParsers.parseVisceralFat(text)
        XCTAssertEqual(result.visceralFatLevel!, 8, accuracy: 0.1)
    }

    // MARK: - Helper Tests

    func testExtractLastNumber() {
        XCTAssertEqual(InBody570RegionParsers.extractLastNumber(from: "Range 50-100 Value 85.2"), 85.2)
        XCTAssertEqual(InBody570RegionParsers.extractLastNumber(from: "No numbers here"), nil)
    }

    func testExtractAllNumbers() {
        let numbers = InBody570RegionParsers.extractAllNumbers(from: "Right Arm  8.22  105.3")
        XCTAssertEqual(numbers.count, 2)
        XCTAssertEqual(numbers[0], 8.22, accuracy: 0.001)
        XCTAssertEqual(numbers[1], 105.3, accuracy: 0.001)
    }
}
