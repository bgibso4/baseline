import XCTest
@testable import Baseline

/// Covers the physical-identity checks that flag wrong-but-confident parser
/// output. Each test pins one specific relationship (weight = fat + lean,
/// tbw = icw + ecw, pbf = bfm/weight*100, etc.) — individually verified so
/// regressions point straight to the broken check.
final class CrossFieldValidatorTests: XCTestCase {

    // MARK: - All consistent

    func testAllConsistent_returnsEmptySet() {
        let fields: [String: String] = [
            "weightKg": "90.0",
            "bodyFatMassKg": "15.0",
            "leanBodyMassKg": "75.0",
            "totalBodyWaterL": "55.0",
            "dryLeanMassKg": "20.0",
            "intracellularWaterL": "34.0",
            "extracellularWaterL": "21.0",
            "bodyFatPct": "16.7",   // 15/90*100 = 16.667
            "ecwTbwRatio": "0.382", // 21/55 = 0.3818
        ]
        XCTAssertEqual(CrossFieldValidator.validate(fields), [])
    }

    // MARK: - Weight = fat + lean

    func testWeightMismatch_flagsAllThree() {
        // weight claimed 90, but fat+lean = 80 — 10kg off, well beyond 2%
        let fields: [String: String] = [
            "weightKg": "90.0",
            "bodyFatMassKg": "15.0",
            "leanBodyMassKg": "65.0",
        ]
        let failing = CrossFieldValidator.validate(fields)
        XCTAssertTrue(failing.contains("weightKg"))
        XCTAssertTrue(failing.contains("bodyFatMassKg"))
        XCTAssertTrue(failing.contains("leanBodyMassKg"))
    }

    func testWeightWithinTwoPercent_passes() {
        // 90.0 vs 89.5 (0.5kg off, 0.56% — within 2%, passes)
        let fields: [String: String] = [
            "weightKg": "90.0",
            "bodyFatMassKg": "15.0",
            "leanBodyMassKg": "74.5",
        ]
        XCTAssertFalse(CrossFieldValidator.validate(fields).contains("weightKg"))
    }

    func testMissingWeight_checkSkipped() {
        // bfm + lbm = 80, but no weight to compare against — skip the check
        let fields: [String: String] = [
            "bodyFatMassKg": "15.0",
            "leanBodyMassKg": "65.0",
        ]
        let failing = CrossFieldValidator.validate(fields)
        XCTAssertFalse(failing.contains("bodyFatMassKg"))
        XCTAssertFalse(failing.contains("leanBodyMassKg"))
    }

    // MARK: - Lean = dry + water

    func testLeanBodyMassMismatch_flagsTriple() {
        let fields: [String: String] = [
            "leanBodyMassKg": "75.0",
            "dryLeanMassKg": "20.0",
            "totalBodyWaterL": "45.0", // 20 + 45 = 65, should be 75
        ]
        let failing = CrossFieldValidator.validate(fields)
        XCTAssertTrue(failing.contains("leanBodyMassKg"))
        XCTAssertTrue(failing.contains("dryLeanMassKg"))
        XCTAssertTrue(failing.contains("totalBodyWaterL"))
    }

    // MARK: - TBW = ICW + ECW

    func testTotalBodyWaterMismatch_flagsAllThree() {
        let fields: [String: String] = [
            "totalBodyWaterL": "55.0",
            "intracellularWaterL": "30.0",
            "extracellularWaterL": "30.0", // 30+30=60, should be 55
        ]
        let failing = CrossFieldValidator.validate(fields)
        XCTAssertTrue(failing.contains("totalBodyWaterL"))
        XCTAssertTrue(failing.contains("intracellularWaterL"))
        XCTAssertTrue(failing.contains("extracellularWaterL"))
    }

    // MARK: - PBF = BFM/weight * 100

    func testBodyFatPctMismatch_flagsPBFOnly() {
        // Real clean-sheet regression: BFM=12, weight=199.4, pbf read as 18
        // Expected PBF = 12/199.4*100 = 6.02, delta to 18 is 11.98 → flag
        let fields: [String: String] = [
            "weightKg": "199.4",
            "bodyFatMassKg": "12.0",
            "leanBodyMassKg": "187.4",
            "bodyFatPct": "18.0",
        ]
        let failing = CrossFieldValidator.validate(fields)
        XCTAssertTrue(failing.contains("bodyFatPct"), "PBF must flag when BFM/weight*100 doesn't match the parsed PBF")
        XCTAssertFalse(failing.contains("weightKg"), "Weight is consistent with BFM+LBM, should not flag")
        XCTAssertFalse(failing.contains("bodyFatMassKg"), "BFM consistent with weight-LBM, should not flag")
    }

    func testBodyFatPctWithinOnePoint_passes() {
        // Rounding wiggle: BFM/weight = 6.02, pbf = 6.1. Delta 0.08, within 1.0
        let fields: [String: String] = [
            "weightKg": "199.4",
            "bodyFatMassKg": "12.0",
            "bodyFatPct": "6.1",
        ]
        XCTAssertFalse(CrossFieldValidator.validate(fields).contains("bodyFatPct"))
    }

    func testBodyFatPctZero_flagged() {
        // Real marked-sheet regression: PBF extracted as 0 when BFM=14.2
        let fields: [String: String] = [
            "weightKg": "197.2",
            "bodyFatMassKg": "14.2",
            "bodyFatPct": "0.0",
        ]
        XCTAssertTrue(CrossFieldValidator.validate(fields).contains("bodyFatPct"))
    }

    // MARK: - ECW/TBW ratio

    func testEcwTbwRatioMismatch_flags() {
        let fields: [String: String] = [
            "totalBodyWaterL": "55.0",
            "extracellularWaterL": "21.0", // real ratio = 0.3818
            "ecwTbwRatio": "0.500",        // claim 0.500 — way off
        ]
        XCTAssertTrue(CrossFieldValidator.validate(fields).contains("ecwTbwRatio"))
    }

    func testEcwTbwRatioWithinTolerance_passes() {
        let fields: [String: String] = [
            "totalBodyWaterL": "55.0",
            "extracellularWaterL": "21.0", // real ratio = 0.3818
            "ecwTbwRatio": "0.382",        // rounded
        ]
        XCTAssertFalse(CrossFieldValidator.validate(fields).contains("ecwTbwRatio"))
    }

    // MARK: - Partial data

    func testEmptyFields_returnsEmpty() {
        XCTAssertEqual(CrossFieldValidator.validate([:]), [])
    }

    func testNonNumericValues_ignored() {
        let fields: [String: String] = [
            "weightKg": "nope",
            "bodyFatMassKg": "15.0",
            "leanBodyMassKg": "75.0",
        ]
        // weight isn't parseable, so weight check skipped — no flags
        XCTAssertEqual(CrossFieldValidator.validate(fields), [])
    }
}
