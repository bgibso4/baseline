import XCTest
@testable import Baseline

final class GreetingTests: XCTestCase {
    /// Fixed date at the given hour — keeps assertions independent of run time.
    private func date(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: hour))!
    }

    func testMorningSpansFiveToElevenInclusive() {
        XCTAssertEqual(Greeting.salutation(at: date(hour: 5)), "Good morning")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 11)), "Good morning")
    }

    func testAfternoonSpansNoonToFourInclusive() {
        XCTAssertEqual(Greeting.salutation(at: date(hour: 12)), "Good afternoon")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 16)), "Good afternoon")
    }

    func testEveningSpansSeventeenThroughFourWrappingMidnight() {
        XCTAssertEqual(Greeting.salutation(at: date(hour: 17)), "Good evening")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 23)), "Good evening")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 0)), "Good evening")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 4)), "Good evening")
    }

    func testDisplayWithNameAddsCommaAndNameLine() {
        let display = Greeting.display(name: "Ben", at: date(hour: 9))
        XCTAssertEqual(display.salutationLine, "Good morning,")
        XCTAssertEqual(display.nameLine, "Ben")
        XCTAssertEqual(display.accessibilityLabel, "Good morning, Ben")
    }

    func testDisplayWithoutNameHasNoDanglingComma() {
        let display = Greeting.display(name: "", at: date(hour: 9))
        XCTAssertEqual(display.salutationLine, "Good morning")
        XCTAssertNil(display.nameLine)
        XCTAssertEqual(display.accessibilityLabel, "Good morning")
    }

    func testDisplayTreatsWhitespaceOnlyNameAsUnset() {
        let display = Greeting.display(name: "   ", at: date(hour: 21))
        XCTAssertEqual(display.salutationLine, "Good evening")
        XCTAssertNil(display.nameLine)
    }

    func testDisplayTrimsPaddedName() {
        let display = Greeting.display(name: "  Ben ", at: date(hour: 13))
        XCTAssertEqual(display.salutationLine, "Good afternoon,")
        XCTAssertEqual(display.nameLine, "Ben")
    }
}
