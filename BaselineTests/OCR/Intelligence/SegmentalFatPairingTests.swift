import XCTest
@testable import Baseline

final class SegmentalFatPairingTests: XCTestCase {

    private let lbs: [Double] = [0.2, 0.2, 6.8, 2.2, 2.2]
    private let percents: [Double] = [14.4, 14.4, 65.7, 50.4, 50.9]

    func testFiveAndFivePairTopToBottom() {
        let fields = SegmentalFatPairing.fields(lbs: lbs, percents: percents)

        XCTAssertEqual(fields.count, 10)
        XCTAssertEqual(fields["rightArmFatKg"], 0.2)
        XCTAssertEqual(fields["trunkFatKg"], 6.8)
        XCTAssertEqual(fields["trunkFatPct"], 65.7)
        XCTAssertEqual(fields["leftLegFatPct"], 50.9)
    }

    func testTrailingLOfLbsReadAsADigitIsRemoved() throws {
        // "( 0.2lbs)" is often read as 0.21: the sheet prints one decimal
        // place, so a second one is the "l" of "lbs".
        let fields = SegmentalFatPairing.fields(lbs: [0.21, 0.21, 6.81, 2.21, 2.21], percents: percents)

        XCTAssertEqual(try XCTUnwrap(fields["rightArmFatKg"]), 0.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(fields["trunkFatKg"]), 6.8, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(fields["leftLegFatKg"]), 2.2, accuracy: 0.0001)
    }

    func testPercentsThatRepeatTheLbsColumnAreNotTrusted() {
        // Both questions are asked of the same crop; an answer with the wrong column must not pass as percentages.
        XCTAssertTrue(SegmentalFatPairing.fields(lbs: lbs, percents: lbs).isEmpty)
        XCTAssertTrue(SegmentalFatPairing.fields(lbs: lbs, percents: [0.21, 0.21, 6.81, 2.21, 2.21]).isEmpty)
    }

    func testEachColumnStandsOrFallsAlone() {
        let onlyPercents = SegmentalFatPairing.fields(lbs: [0.2, 0.2], percents: percents)
        XCTAssertEqual(Set(onlyPercents.keys), ["rightArmFatPct", "leftArmFatPct", "trunkFatPct", "rightLegFatPct", "leftLegFatPct"])

        let onlyLbs = SegmentalFatPairing.fields(lbs: lbs, percents: percents + [1.0])
        XCTAssertEqual(Set(onlyLbs.keys), ["rightArmFatKg", "leftArmFatKg", "trunkFatKg", "rightLegFatKg", "leftLegFatKg"])
    }

    func testImplausibleColumnGivesNothing() {
        XCTAssertTrue(SegmentalFatPairing.fields(lbs: [0.2, 0.2, 680, 2.2, 2.2], percents: []).isEmpty)
    }
}
