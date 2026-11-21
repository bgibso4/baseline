import XCTest
@testable import Baseline

final class SegmentalLeanPairingTests: XCTestCase {

    private let sheet: [Double] = [11.49, 138.0, 11.38, 136.6, 80.9, 121.9, 27.67, 119.5, 28.02, 121.1]

    func testTenNumbersPairTopToBottom() {
        let fields = SegmentalLeanPairing.fields(from: sheet)

        XCTAssertEqual(fields.count, 10)
        XCTAssertEqual(fields["rightArmLeanKg"], 11.49)
        XCTAssertEqual(fields["rightArmLeanPct"], 138.0)
        XCTAssertEqual(fields["trunkLeanKg"], 80.9)
        XCTAssertEqual(fields["leftLegLeanPct"], 121.1)
    }

    func testFiveMassesAloneFillOnlyTheMassFields() {
        // Seen on device: the model lists one figure per body part and omits the other.
        let fields = SegmentalLeanPairing.fields(from: [8.42, 8.31, 61.2, 21.06, 20.94])

        XCTAssertEqual(fields, [
            "rightArmLeanKg": 8.42, "leftArmLeanKg": 8.31, "trunkLeanKg": 61.2,
            "rightLegLeanKg": 21.06, "leftLegLeanKg": 20.94
        ])
    }

    func testFivePercentsAloneFillOnlyThePercentFields() {
        let fields = SegmentalLeanPairing.fields(from: [104.1, 103.0, 101.4, 98.7, 98.2])

        XCTAssertEqual(fields.count, 5)
        XCTAssertEqual(fields["rightArmLeanPct"], 104.1)
        XCTAssertEqual(fields["leftLegLeanPct"], 98.2)
    }

    func testFiveMixedNumbersGiveNothing() {
        XCTAssertTrue(SegmentalLeanPairing.fields(from: [8.42, 103.0, 61.2, 21.06, 98.2]).isEmpty)
    }

    func testWrongCountGivesNothing() {
        XCTAssertTrue(SegmentalLeanPairing.fields(from: Array(sheet.dropLast())).isEmpty)
        XCTAssertTrue(SegmentalLeanPairing.fields(from: sheet + [125.4]).isEmpty)
        XCTAssertTrue(SegmentalLeanPairing.fields(from: []).isEmpty)
    }

    func testImplausibleSequenceGivesNothing() {
        // A dropped number shifts every later one into the wrong slot; the
        // ranges notice (a trunk of 27.67 lbs, a leg of 119.5 lbs) and no
        // value from a list in that state can be trusted.
        let shifted: [Double] = [11.49, 138.0, 11.38, 136.6, 121.9, 27.67, 119.5, 28.02, 121.1, 125.4]

        XCTAssertTrue(SegmentalLeanPairing.fields(from: shifted).isEmpty)
    }

    func testAxisTickInTheListGivesNothing() {
        var withTick = sheet
        withTick[1] = 1300   // a merged tick mark, far outside any % range

        XCTAssertTrue(SegmentalLeanPairing.fields(from: withTick).isEmpty)
    }

    func testPairsListedPercentFirstAreStillAssignedCorrectly() {
        // Where the % figure is printed fractionally higher than the lbs
        // figure, the model lists each pair the other way round.
        let percentFirst: [Double] = [104.1, 8.42, 103.0, 8.31, 101.4, 61.2, 98.7, 21.06, 98.2, 20.94]

        let fields = SegmentalLeanPairing.fields(from: percentFirst)

        XCTAssertEqual(fields["rightArmLeanKg"], 8.42)
        XCTAssertEqual(fields["rightArmLeanPct"], 104.1)
        XCTAssertEqual(fields["trunkLeanKg"], 61.2)
        XCTAssertEqual(fields["trunkLeanPct"], 101.4)
        XCTAssertEqual(fields["leftLegLeanKg"], 20.94)
    }

    func testTrunkFollowsTheOrderOfTheLimbs() {
        // A heavily muscled trunk can weigh more in lbs than its % figure, so
        // "smaller is lbs" cannot be applied to the trunk on its own.
        let bigTrunk: [Double] = [14.2, 150.0, 14.0, 148.0, 118.0, 112.0, 35.1, 130.0, 35.0, 129.0]

        let fields = SegmentalLeanPairing.fields(from: bigTrunk)

        XCTAssertEqual(fields["trunkLeanKg"], 118.0)
        XCTAssertEqual(fields["trunkLeanPct"], 112.0)
    }

    func testLimbsThatDisagreeOnOrderGiveNothing() {
        let mixed: [Double] = [11.49, 138.0, 136.6, 11.38, 80.9, 121.9, 119.5, 27.67, 28.02, 121.1]

        XCTAssertTrue(SegmentalLeanPairing.fields(from: mixed).isEmpty)
    }
}
