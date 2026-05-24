import XCTest
@testable import Baseline

/// Unit tests for the pure Trends presentation formatting extracted from
/// `TrendsView`. Date-range substrings are locale/timezone dependent, so these
/// assert on the deterministic structural parts (suffixes, separators, value
/// formatting) rather than the full rendered date string.
final class TrendsFormattingTests: XCTestCase {

    // MARK: - value

    func testValueOneDecimal() {
        XCTAssertEqual(TrendsFormatting.value(180), "180.0")
        XCTAssertEqual(TrendsFormatting.value(12.34), "12.3")
        XCTAssertEqual(TrendsFormatting.value(12.35), "12.3") // banker's rounding of %.1f
    }

    // MARK: - goalLabel

    func testGoalLabelWholeNumberAtOrAbove10UsesNoDecimals() {
        XCTAssertEqual(TrendsFormatting.goalLabel(180, unit: "lb"), "180 lb")
    }

    func testGoalLabelBelow10KeepsDecimalEvenWhenWhole() {
        // value < 10 always shows one decimal, even for round values.
        XCTAssertEqual(TrendsFormatting.goalLabel(9, unit: "x"), "9.0 x")
    }

    func testGoalLabelNonWholeUsesOneDecimal() {
        XCTAssertEqual(TrendsFormatting.goalLabel(12.5, unit: "%"), "12.5 %")
        XCTAssertEqual(TrendsFormatting.goalLabel(180.4, unit: "lb"), "180.4 lb")
    }

    // MARK: - periodSubtitle

    func testPeriodSubtitleEmptyForFewerThanTwoPoints() {
        XCTAssertEqual(TrendsFormatting.periodSubtitle(points: [], unit: "lb"), "")
        let single = [TrendDataPoint(date: Date(), value: 180)]
        XCTAssertEqual(TrendsFormatting.periodSubtitle(points: single, unit: "lb"), "")
    }

    func testPeriodSubtitleSparseShowsEntryCount() {
        let base = Date()
        let points = (0..<3).map { i in
            TrendDataPoint(date: base.addingTimeInterval(Double(i) * 86_400), value: 180)
        }
        let subtitle = TrendsFormatting.periodSubtitle(points: points, unit: "lb")
        // Date range is omitted (the window stepper shows it); just the count.
        XCTAssertEqual(subtitle, "3 entries")
    }

    func testPeriodSubtitleDenseShowsPerWeekRate() {
        // 8 points across exactly 7 days (day 0…7): span = 1 week, so the
        // per-week rate equals the total delta.
        let base = Date()
        let points = (0...7).map { i in
            TrendDataPoint(date: base.addingTimeInterval(Double(i) * 86_400), value: 180 - Double(i))
        }
        // delta = 173 - 180 = -7 over 1 week → "−7.0 lb / week" (minus is U+2212).
        // No date range — the window stepper conveys the span.
        let subtitle = TrendsFormatting.periodSubtitle(points: points, unit: "lb")
        XCTAssertEqual(subtitle, "\u{2212}7.0 lb / week")
        XCTAssertFalse(subtitle.contains("-"), "ASCII hyphen should be replaced with U+2212")
    }
}
