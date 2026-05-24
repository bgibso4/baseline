import Foundation

/// Pure presentation formatting for the Trends screen.
///
/// Extracted from `TrendsView` so the value/label/subtitle string-building is
/// testable without rendering SwiftUI (see `TrendsFormattingTests`). These are
/// pure functions — no view state, no side effects.
enum TrendsFormatting {
    /// Format a value for display (1 decimal place).
    static func value(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Goal-line label: whole number for round values ≥ 10, else 1 decimal,
    /// suffixed with the unit (e.g. "180 lb", "12.5 %").
    static func goalLabel(_ value: Double, unit: String) -> String {
        let formatted = value == value.rounded() && value >= 10
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return formatted + " " + unit
    }

    /// Builds the "Mar 6 – Apr 4 · -0.8 lb / week" string under the hero.
    static func periodSubtitle(points: [TrendDataPoint], unit: String) -> String {
        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return ""
        }
        let spanDays = max(1, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
        let dateRange = "\(DateFormatting.shortDay(first.date)) \u{2013} \(DateFormatting.shortDay(last.date))"

        if points.count < 7 {
            return "\(dateRange) \u{00B7} \(points.count) entries"
        }

        let delta = last.value - first.value
        let weeks = Double(spanDays) / 7.0
        let perWeek = weeks > 0 ? delta / weeks : 0
        let perWeekStr = UnitConversion.formatDelta(perWeek)
            .replacingOccurrences(of: "-", with: "\u{2212}")
        return "\(dateRange) \u{00B7} \(perWeekStr) \(unit) / week"
    }
}
