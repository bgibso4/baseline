import SwiftUI
import Charts

// MARK: - Chart Interactivity (#63 — drag-to-inspect crosshair)

/// Bundle of context the crosshair needs to render its rule line and the
/// solid filled dots on each series at the selected x. The actual date +
/// value display happens in the hero block above the chart (Whoop-style),
/// not in a floating callout — keeps the value text always-visible and
/// dodges annotation/overflow/clipping pitfalls.
struct CrosshairContext {
    let primaryPoints: [TrendDataPoint]
    let secondaryPoints: [TrendDataPoint]
    let secondaryColor: Color
    /// Dual-axis mode normalises both series into 0...1. Crosshair y-positions
    /// must match so the highlighted dot lands on the visible line.
    let isDualAxis: Bool
    let primaryRange: ClosedRange<Double>
    let secondaryRange: ClosedRange<Double>
}

/// Crosshair marks (dashed vertical rule + solid filled dot per series)
/// added INSIDE the existing `Chart {}` block when a date is selected.
/// No-op when `selectedDate` is nil so the chart renders cleanly on
/// first appear. Date + value text comes from the parent view's hero
/// swap; this builder is purely visual chrome on the chart.
@ChartContentBuilder
func crosshairMarks(selectedDate: Date?, context: CrosshairContext) -> some ChartContent {
    if let selectedDate, let snapped = nearestPoint(to: selectedDate, in: context.primaryPoints) {
        let primaryY = context.isDualAxis
            ? normaliseForDualAxis(snapped.value, range: context.primaryRange)
            : snapped.value

        // Subtle dashed vertical line through the selected x.
        RuleMark(x: .value("Selected", snapped.date))
            .foregroundStyle(CadreColors.textPrimary.opacity(0.35))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Solid filled dot on the primary line at the snapped x.
        PointMark(
            x: .value("Date", snapped.date),
            y: .value("Value", primaryY)
        )
        .foregroundStyle(CadreColors.accent)
        .symbolSize(120)

        // Solid filled dot on the secondary line (compare mode only).
        if let secSnapped = nearestPoint(to: selectedDate, in: context.secondaryPoints) {
            let secY = context.isDualAxis
                ? normaliseForDualAxis(secSnapped.value, range: context.secondaryRange)
                : secSnapped.value
            PointMark(
                x: .value("Date", secSnapped.date),
                y: .value("Value", secY)
            )
            .foregroundStyle(context.secondaryColor)
            .symbolSize(120)
        }
    }
}

// MARK: - View modifier

/// Wires `chartXSelection` for drag-to-inspect plus a haptic tick when the
/// snapped day under the finger changes. Without `chartScrollableAxes` in
/// the modifier chain, a regular drag activates selection — no long-press
/// required.
struct TrendsChartInteractivity: ViewModifier {
    @Binding var selectedDate: Date?

    @State private var lastHapticDay: Date?

    func body(content: Content) -> some View {
        content
            .chartXSelection(value: $selectedDate)
            .onChange(of: selectedDate) { _, newValue in
                fireHapticIfDayChanged(newValue)
            }
    }

    /// Fire a selection tick when the snapped day under the finger changes.
    /// Day-resolution snapping matches the data-point granularity of all
    /// metrics in the app (one entry per day max).
    private func fireHapticIfDayChanged(_ newValue: Date?) {
        guard let newValue else {
            lastHapticDay = nil
            return
        }
        let day = Calendar.current.startOfDay(for: newValue)
        if day != lastHapticDay {
            lastHapticDay = day
            Haptics.selection()
        }
    }
}

extension View {
    /// Convenience for applying `TrendsChartInteractivity` to a chart.
    func trendsChartInteractivity(selectedDate: Binding<Date?>) -> some View {
        modifier(TrendsChartInteractivity(selectedDate: selectedDate))
    }
}

// MARK: - Helpers

/// Find the data point whose date is closest to `target`. Returns nil when
/// the array is empty. Public so the parent view can use the same snapping
/// logic for its inspect-mode hero.
func nearestPoint(to target: Date, in points: [TrendDataPoint]) -> TrendDataPoint? {
    points.min {
        abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
    }
}

/// Map a real value into the 0...1 dual-axis space used by the Trends
/// chart when comparing two metrics with different scales.
private func normaliseForDualAxis(_ value: Double, range: ClosedRange<Double>) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return 0.5 }
    return (value - range.lowerBound) / span
}
