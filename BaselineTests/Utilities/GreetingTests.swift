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
}
