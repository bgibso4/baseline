import XCTest
@testable import Baseline

final class TrendsAxisScaleTests: XCTestCase {

    // MARK: - normalize

    func testNormalizeMapsRangeToZeroOne() {
        XCTAssertEqual(TrendsAxisScale.normalize(0, min: 0, max: 10), 0.0, accuracy: 1e-9)
        XCTAssertEqual(TrendsAxisScale.normalize(5, min: 0, max: 10), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TrendsAxisScale.normalize(10, min: 0, max: 10), 1.0, accuracy: 1e-9)
    }

    func testNormalizeHandlesNonZeroFloor() {
        XCTAssertEqual(TrendsAxisScale.normalize(150, min: 100, max: 200), 0.5, accuracy: 1e-9)
    }

    func testNormalizeZeroWidthRangeReturnsMidpoint() {
        // Degenerate range (single value) → 0.5 so the point sits centered.
        XCTAssertEqual(TrendsAxisScale.normalize(180, min: 180, max: 180), 0.5, accuracy: 1e-9)
    }

    // MARK: - axisTickValues

    func testAxisTickValuesEvenlySpaced() {
        let ticks = TrendsAxisScale.axisTickValues(min: 0, max: 30, count: 4)
        XCTAssertEqual(ticks, [0, 10, 20, 30])
    }

    func testAxisTickValuesDefaultCountIsFour() {
        XCTAssertEqual(TrendsAxisScale.axisTickValues(min: 0, max: 30).count, 4)
    }

    func testAxisTickValuesZeroWidthRangeReturnsSingle() {
        XCTAssertEqual(TrendsAxisScale.axisTickValues(min: 5, max: 5), [5])
    }
}
