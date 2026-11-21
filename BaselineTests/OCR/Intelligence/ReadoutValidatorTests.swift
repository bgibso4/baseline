import XCTest
@testable import Baseline

final class ReadoutValidatorTests: XCTestCase {

    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19))!

    private func assemble(_ readouts: [SheetSection: SectionReadout]) -> InBodyParseResult {
        ReadoutValidator.assemble(readouts, now: now)
    }

    func testInRangeValueIsTrusted() {
        let result = assemble([.bodyCompositionTotals: SectionReadout(values: ["weightKg": 199.4])])

        XCTAssertEqual(result.weightKg, 199.4)
        XCTAssertEqual(result.confidence["weightKg"], 0.9)
        XCTAssertTrue(result.isSelfValidated)
    }

    func testOutOfRangeValueIsDropped() {
        let result = assemble([.segmentalLean: SectionReadout(values: ["leftArmLeanKg": 139.5])])

        XCTAssertNil(result.leftArmLeanKg)
        XCTAssertNil(result.confidence["leftArmLeanKg"])
    }

    func testZeroIsDroppedEvenWhenInRange() {
        // The model answers 0.0 for values it cannot read; 0 is inside the fat-mass range.
        let result = assemble([.bodyCompositionTotals: SectionReadout(values: ["bodyFatMassKg": 0.0])])

        XCTAssertNil(result.bodyFatMassKg)
    }

    func testRepeatedMismatchFlags() {
        let result = assemble([
            .bodyCompositionTotals: SectionReadout(values: ["weightKg": 199.4]),
            .muscleFat: SectionReadout(repeated: ["weightKg": 197.2])
        ])

        XCTAssertEqual(result.weightKg, 199.4)
        XCTAssertEqual(result.confidence["weightKg"], 0.3)
    }

    func testRepeatedAgreementIsTrusted() {
        let result = assemble([
            .bodyCompositionTotals: SectionReadout(values: ["weightKg": 199.4]),
            .muscleFat: SectionReadout(repeated: ["weightKg": 199.4])
        ])

        XCTAssertEqual(result.confidence["weightKg"], 0.9)
    }

    func testRepeatedFillsMissing() {
        let result = assemble([.muscleFat: SectionReadout(repeated: ["weightKg": 199.4])])

        XCTAssertEqual(result.weightKg, 199.4)
        XCTAssertEqual(result.confidence["weightKg"], 0.3)
    }

    func testOutOfRangeRepeatIsIgnored() {
        let result = assemble([
            .bodyCompositionTotals: SectionReadout(values: ["weightKg": 199.4]),
            .muscleFat: SectionReadout(repeated: ["weightKg": 5701])
        ])

        XCTAssertEqual(result.confidence["weightKg"], 0.9)
    }

    func testDateWindow() {
        func scanDate(_ year: Int, _ month: Int, _ day: Int) -> Date? {
            let date = DateComponents(year: year, month: month, day: day)
            return assemble([.header: SectionReadout(testDate: date)]).scanDate
        }

        XCTAssertEqual(scanDate(2026, 4, 14), Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 14)))
        XCTAssertNotNil(scanDate(2024, 2, 20))
        XCTAssertNil(scanDate(2020, 1, 1), "more than five years old")
        XCTAssertNil(scanDate(2027, 1, 1), "in the future")
        XCTAssertNil(scanDate(2026, 13, 1), "not a real date")
        XCTAssertNil(scanDate(2026, 0, 22), "not a real date")
        XCTAssertNil(scanDate(2026, 2, 30), "not a real date")
    }

    func testSaneRangeCoversEveryFieldExceptScore() {
        for key in InBodyParseResult.allFieldKeys where key != "inBodyScore" {
            XCTAssertNotNil(InBodyParseResult.saneRange(forKey: key), key)
        }
        XCTAssertNil(InBodyParseResult.saneRange(forKey: "inBodyScore"))
    }
}
