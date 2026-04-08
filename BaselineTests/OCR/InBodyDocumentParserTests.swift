import XCTest
@testable import Baseline

final class InBodyDocumentParserTests: XCTestCase {

    // MARK: - Label Mapping

    func testExactLabelMatch() {
        XCTAssertEqual(InBodyDocumentParser.fieldKey(for: "Weight"), "weightKg")
    }

    func testLabelMatchIsCaseInsensitive() {
        XCTAssertEqual(InBodyDocumentParser.fieldKey(for: "skeletal muscle mass"), "skeletalMuscleMassKg")
    }

    func testLabelMatchWithTrailingUnits() {
        XCTAssertEqual(InBodyDocumentParser.fieldKey(for: "Weight (kg)"), "weightKg")
    }

    func testUnknownLabelReturnsNil() {
        XCTAssertNil(InBodyDocumentParser.fieldKey(for: "Some Random Text"))
    }

    func testAllCoreLabelsRecognized() {
        let coreLabels: [(String, String)] = [
            ("Weight", "weightKg"),
            ("Skeletal Muscle Mass", "skeletalMuscleMassKg"),
            ("Body Fat Mass", "bodyFatMassKg"),
            ("Percent Body Fat", "bodyFatPct"),
            ("Total Body Water", "totalBodyWaterL"),
            ("BMI", "bmi"),
            ("Basal Metabolic Rate", "basalMetabolicRate"),
        ]
        for (label, expectedKey) in coreLabels {
            XCTAssertEqual(
                InBodyDocumentParser.fieldKey(for: label), expectedKey,
                "Expected '\(label)' → '\(expectedKey)'"
            )
        }
    }

    func testOCRVariantLabels() {
        let variants: [(String, String)] = [
            ("PBF", "bodyFatPct"),
            ("BMR", "basalMetabolicRate"),
            ("ECW/TBW", "ecwTbwRatio"),
            ("ECW/TBW Ratio", "ecwTbwRatio"),
            ("SMI", "skeletalMuscleIndex"),
            ("InBody Score", "inBodyScore"),
            ("ICW", "intracellularWaterL"),
            ("ECW", "extracellularWaterL"),
            ("Dry Lean Mass", "dryLeanMassKg"),
            ("Lean Body Mass", "leanBodyMassKg"),
            ("Visceral Fat Level", "visceralFatLevel"),
        ]
        for (label, expectedKey) in variants {
            XCTAssertEqual(
                InBodyDocumentParser.fieldKey(for: label), expectedKey,
                "Expected '\(label)' → '\(expectedKey)'"
            )
        }
    }

    // MARK: - Numeric Parsing

    func testParseCleanNumber() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("89.5"), 89.5)
    }

    func testParseNumberWithUnits() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("89.5 kg"), 89.5)
    }

    func testParseNumberWithPercent() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("17.1%"), 17.1)
    }

    func testParseInteger() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("1842 kcal"), 1842.0)
    }

    func testParseRatio() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("0.380"), 0.380)
    }

    func testParseEmptyStringReturnsNil() {
        XCTAssertNil(InBodyDocumentParser.parseNumericValue(""))
    }

    func testParseNonNumericReturnsNil() {
        XCTAssertNil(InBodyDocumentParser.parseNumericValue("Normal"))
    }

    // MARK: - setField / getField Round-Trip

    func testSetAndGetAllCoreFields() {
        var result = InBodyParseResult()
        let coreFields: [(String, Double)] = [
            ("weightKg", 89.5),
            ("skeletalMuscleMassKg", 47.3),
            ("bodyFatMassKg", 15.2),
            ("bodyFatPct", 17.1),
            ("totalBodyWaterL", 52.4),
            ("bmi", 27.3),
            ("basalMetabolicRate", 1842.0),
        ]
        for (key, value) in coreFields {
            InBodyDocumentParser.setField(key, value: value, on: &result)
            XCTAssertEqual(
                InBodyDocumentParser.getField(key, from: result), value,
                "Round-trip failed for key: \(key)"
            )
        }
    }

    func testSetAndGetSegmentalFields() {
        var result = InBodyParseResult()
        let segmentalFields: [(String, Double)] = [
            ("rightArmLeanKg", 4.1),
            ("leftArmLeanKg", 3.9),
            ("trunkLeanKg", 28.6),
            ("rightLegLeanKg", 10.2),
            ("leftLegLeanKg", 10.0),
            ("ecwTbwRatio", 0.380),
            ("skeletalMuscleIndex", 9.8),
            ("visceralFatLevel", 7.0),
        ]
        for (key, value) in segmentalFields {
            InBodyDocumentParser.setField(key, value: value, on: &result)
            XCTAssertEqual(
                InBodyDocumentParser.getField(key, from: result), value,
                "Round-trip failed for key: \(key)"
            )
        }
    }

    func testGetFieldReturnsNilForUnsetField() {
        let result = InBodyParseResult()
        XCTAssertNil(InBodyDocumentParser.getField("weightKg", from: result))
    }

    func testGetFieldReturnsNilForUnknownKey() {
        let result = InBodyParseResult()
        XCTAssertNil(InBodyDocumentParser.getField("nonexistent", from: result))
    }
}
