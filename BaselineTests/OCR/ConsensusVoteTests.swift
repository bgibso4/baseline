import XCTest
@testable import Baseline

final class ConsensusVoteTests: XCTestCase {

    // MARK: - All Agree

    func testAllThreeAgree_HighConfidence() {
        let r1 = makeResult(weightKg: 80.0, conf: 0.8)
        let r2 = makeResult(weightKg: 80.0, conf: 0.7)
        let r3 = makeResult(weightKg: 80.0, conf: 0.9)

        let voted = InBodyParseResult.consensusVote([r1, r2, r3])

        XCTAssertEqual(voted.weightKg!, 80.0, accuracy: 0.01)
        XCTAssertEqual(voted.confidence["weightKg"], 0.95, "All agree → 0.95")
    }

    func testAllAgreeWithinTolerance() {
        // Values within 1% of each other should be treated as agreeing
        let r1 = makeResult(weightKg: 80.0, conf: 0.8)
        let r2 = makeResult(weightKg: 80.5, conf: 0.8)  // 0.6% diff
        let r3 = makeResult(weightKg: 80.2, conf: 0.8)

        let voted = InBodyParseResult.consensusVote([r1, r2, r3])

        // Should average the agreeing values
        XCTAssertNotNil(voted.weightKg)
        XCTAssertEqual(voted.confidence["weightKg"], 0.95, "Within tolerance → all agree")
    }

    // MARK: - Majority Agrees

    func testTwoOfThreeAgree_MajorityWins() {
        let r1 = makeResult(weightKg: 80.0, conf: 0.8)
        let r2 = makeResult(weightKg: 80.0, conf: 0.7)
        let r3 = makeResult(weightKg: 95.0, conf: 0.9)  // outlier

        let voted = InBodyParseResult.consensusVote([r1, r2, r3])

        XCTAssertEqual(voted.weightKg!, 80.0, accuracy: 0.01, "Majority wins over outlier")
        XCTAssertEqual(voted.confidence["weightKg"], 0.85, "2 of 3 agree → 0.85")
    }

    func testMajorityWinsEvenWithLowerAppleConfidence() {
        // 2 scans agree at 80.0 (low Apple conf) vs 1 at 95.0 (high Apple conf)
        // Consensus should still pick 80.0
        let r1 = makeResult(weightKg: 80.0, conf: 0.3)
        let r2 = makeResult(weightKg: 80.0, conf: 0.4)
        let r3 = makeResult(weightKg: 95.0, conf: 0.99)

        let voted = InBodyParseResult.consensusVote([r1, r2, r3])

        XCTAssertEqual(voted.weightKg!, 80.0, accuracy: 0.01, "Majority beats high Apple conf")
        XCTAssertEqual(voted.confidence["weightKg"], 0.85)
    }

    // MARK: - All Differ

    func testAllDiffer_LowConfidence() {
        let r1 = makeResult(weightKg: 80.0, conf: 0.8)
        let r2 = makeResult(weightKg: 95.0, conf: 0.9)
        let r3 = makeResult(weightKg: 60.0, conf: 0.7)

        let voted = InBodyParseResult.consensusVote([r1, r2, r3])

        // Should pick highest Apple OCR confidence (95.0 at 0.9)
        XCTAssertEqual(voted.weightKg!, 95.0, accuracy: 0.01)
        XCTAssertEqual(voted.confidence["weightKg"], 0.3, "All differ → 0.3 (flagged)")
    }

    // MARK: - Single Scan

    func testSingleScan_KeepsOriginalConfidence() {
        let r1 = makeResult(weightKg: 80.0, conf: 0.8)

        let voted = InBodyParseResult.consensusVote([r1])

        XCTAssertEqual(voted.weightKg, 80.0)
        XCTAssertEqual(voted.confidence["weightKg"], 0.8, "Single scan keeps its confidence")
    }

    // MARK: - Partial Data

    func testFieldOnlyInOneScan() {
        var r1 = InBodyParseResult()
        r1.weightKg = 80.0
        r1.confidence["weightKg"] = 0.8
        r1.bmi = 25.0
        r1.confidence["bmi"] = 0.7

        var r2 = InBodyParseResult()
        r2.weightKg = 80.0
        r2.confidence["weightKg"] = 0.8
        // r2 has no bmi

        let voted = InBodyParseResult.consensusVote([r1, r2])

        XCTAssertEqual(voted.weightKg, 80.0)
        XCTAssertEqual(voted.confidence["weightKg"], 0.95, "Both agree on weight")
        XCTAssertEqual(voted.bmi, 25.0, "BMI from only scan that has it")
        XCTAssertEqual(voted.confidence["bmi"], 0.7, "Single source keeps its confidence")
    }

    // MARK: - User Edited Fields Protected

    func testUserEditedFieldsNotOverwritten() {
        let r1 = makeResult(weightKg: 80.0, conf: 0.9)
        let r2 = makeResult(weightKg: 80.0, conf: 0.9)
        let r3 = makeResult(weightKg: 80.0, conf: 0.9)

        let voted = InBodyParseResult.consensusVote([r1, r2, r3], userEditedFields: ["weightKg"])

        XCTAssertNil(voted.weightKg, "User-edited field should not be set by consensus")
    }

    // MARK: - Two Scans

    func testTwoScansAgree() {
        let r1 = makeResult(weightKg: 80.0, conf: 0.8)
        let r2 = makeResult(weightKg: 80.0, conf: 0.7)

        let voted = InBodyParseResult.consensusVote([r1, r2])

        XCTAssertEqual(voted.weightKg, 80.0)
        XCTAssertEqual(voted.confidence["weightKg"], 0.95, "Both agree → all agree")
    }

    func testTwoScansDisagree() {
        let r1 = makeResult(weightKg: 80.0, conf: 0.8)
        let r2 = makeResult(weightKg: 95.0, conf: 0.9)

        let voted = InBodyParseResult.consensusVote([r1, r2])

        XCTAssertEqual(voted.weightKg, 95.0, "Higher Apple conf wins when all differ")
        XCTAssertEqual(voted.confidence["weightKg"], 0.3, "Disagreement → low confidence")
    }

    // MARK: - Empty

    func testEmptyResults() {
        let voted = InBodyParseResult.consensusVote([])
        XCTAssertNil(voted.weightKg)
    }

    // MARK: - Multiple Fields

    func testMultipleFieldsIndependentVoting() {
        var r1 = InBodyParseResult()
        r1.weightKg = 80.0; r1.confidence["weightKg"] = 0.8
        r1.bodyFatPct = 18.5; r1.confidence["bodyFatPct"] = 0.8

        var r2 = InBodyParseResult()
        r2.weightKg = 80.0; r2.confidence["weightKg"] = 0.7
        r2.bodyFatPct = 22.0; r2.confidence["bodyFatPct"] = 0.9  // disagrees on body fat

        var r3 = InBodyParseResult()
        r3.weightKg = 80.0; r3.confidence["weightKg"] = 0.9
        r3.bodyFatPct = 18.5; r3.confidence["bodyFatPct"] = 0.7

        let voted = InBodyParseResult.consensusVote([r1, r2, r3])

        XCTAssertEqual(voted.weightKg!, 80.0, accuracy: 0.01)
        XCTAssertEqual(voted.confidence["weightKg"], 0.95, "Weight: all agree")

        XCTAssertEqual(voted.bodyFatPct!, 18.5, accuracy: 0.01, "Body fat: majority wins")
        XCTAssertEqual(voted.confidence["bodyFatPct"], 0.85, "Body fat: 2 of 3 agree")
    }

    // MARK: - Helpers

    private func makeResult(weightKg: Double, conf: Float) -> InBodyParseResult {
        var r = InBodyParseResult()
        r.weightKg = weightKg
        r.confidence["weightKg"] = conf
        return r
    }
}
