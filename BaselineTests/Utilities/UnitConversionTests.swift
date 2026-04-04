import XCTest
@testable import Baseline

final class UnitConversionTests: XCTestCase {
    func testLbToKg() {
        XCTAssertEqual(UnitConversion.lbToKg(197.4), 89.5, accuracy: 0.1)
    }

    func testKgToLb() {
        XCTAssertEqual(UnitConversion.kgToLb(89.5), 197.3, accuracy: 0.1)
    }

    func testRoundTrip() {
        let original = 185.0
        let converted = UnitConversion.kgToLb(UnitConversion.lbToKg(original))
        XCTAssertEqual(converted, original, accuracy: 0.01)
    }

    func testFormatWeight() {
        XCTAssertEqual(UnitConversion.formatWeight(197.4, unit: "lb"), "197.4")
        XCTAssertEqual(UnitConversion.formatWeight(197.0, unit: "lb"), "197.0")
        XCTAssertEqual(UnitConversion.formatWeight(89.53, unit: "kg"), "89.5")
    }

    func testFormatDelta() {
        XCTAssertEqual(UnitConversion.formatDelta(0.6), "+0.6")
        XCTAssertEqual(UnitConversion.formatDelta(-1.2), "-1.2")
        XCTAssertEqual(UnitConversion.formatDelta(0.0), "0.0")
    }
}
