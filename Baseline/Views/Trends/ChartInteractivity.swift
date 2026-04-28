import SwiftUI
import Charts

// MARK: - Chart Interactivity (#62 horizontal scroll, #63 drag-to-inspect)

/// Bundle of context the crosshair needs to render its rule, highlighted
/// points, and floating callout. Built once per chart render in TrendsView
/// and passed through `crosshairMarks`.
struct CrosshairContext {
    let primaryPoints: [TrendDataPoint]
    let secondaryPoints: [TrendDataPoint]
    let primaryUnit: String
    let primaryLabel: String
    let secondaryUnit: String
    let secondaryLabel: String?
    let secondaryColor: Color
    /// Dual-axis mode normalises both series into 0...1. Crosshair y-positions
    /// must match so the highlighted ring lands on the visible line.
    let isDualAxis: Bool
    let primaryRange: ClosedRange<Double>
    let secondaryRange: ClosedRange<Double>
}

/// Crosshair marks (vertical rule + highlighted points + floating callout)
/// that get added INSIDE the existing `Chart {}` block when a date is
/// selected. No-op when `selectedDate` is nil so the chart renders cleanly
/// on first appear.
@ChartContentBuilder
func crosshairMarks(selectedDate: Date?, context: CrosshairContext) -> some ChartContent {
    if let selectedDate, let snapped = nearestPoint(to: selectedDate, in: context.primaryPoints) {
        let primaryY = context.isDualAxis
            ? normaliseForDualAxis(snapped.value, range: context.primaryRange)
            : snapped.value

        // Vertical rule line, with the floating callout anchored at the top.
        RuleMark(x: .value("Selected", snapped.date))
            .foregroundStyle(CadreColors.textPrimary.opacity(0.35))
            .lineStyle(StrokeStyle(lineWidth: 1))
            .annotation(
                position: .top,
                spacing: 6,
                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
            ) {
                CrosshairCallout(
                    primaryDate: snapped.date,
                    primaryValue: snapped.value,
                    primaryUnit: context.primaryUnit,
                    primaryLabel: context.primaryLabel,
                    secondaryValue: nearestPoint(to: selectedDate, in: context.secondaryPoints)?.value,
                    secondaryUnit: context.secondaryUnit,
                    secondaryLabel: context.secondaryLabel,
                    secondaryColor: context.secondaryColor
                )
            }

        // Highlighted ring on the primary series.
        PointMark(
            x: .value("Date", snapped.date),
            y: .value("Value", primaryY)
        )
        .foregroundStyle(CadreColors.accent)
        .symbolSize(160)
        .symbol {
            ZStack {
                Circle().fill(CadreColors.card)
                Circle().stroke(CadreColors.accent, lineWidth: 2)
            }
            .frame(width: 14, height: 14)
        }

        // Highlighted ring on the secondary series (compare mode only).
        if let secSnapped = nearestPoint(to: selectedDate, in: context.secondaryPoints) {
            let secY = context.isDualAxis
                ? normaliseForDualAxis(secSnapped.value, range: context.secondaryRange)
                : secSnapped.value
            PointMark(
                x: .value("Date", secSnapped.date),
                y: .value("Value", secY)
            )
            .foregroundStyle(context.secondaryColor)
            .symbolSize(140)
            .symbol {
                ZStack {
                    Circle().fill(CadreColors.card)
                    Circle().stroke(context.secondaryColor, lineWidth: 2)
                }
                .frame(width: 12, height: 12)
            }
        }
    }
}

/// Two-line floating callout shown above the crosshair rule. Stacks
/// primary + secondary when compare mode is active (matches Apple Health).
private struct CrosshairCallout: View {
    let primaryDate: Date
    let primaryValue: Double
    let primaryUnit: String
    let primaryLabel: String
    let secondaryValue: Double?
    let secondaryUnit: String
    let secondaryLabel: String?
    let secondaryColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(primaryDate, format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CadreColors.textTertiary)
                .tracking(0.3)

            valueRow(
                color: CadreColors.accent,
                label: primaryLabel,
                value: primaryValue,
                unit: primaryUnit
            )

            if let secondaryValue, let secondaryLabel {
                valueRow(
                    color: secondaryColor,
                    label: secondaryLabel,
                    value: secondaryValue,
                    unit: secondaryUnit
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(CadreColors.cardElevated)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
        )
    }

    private func valueRow(color: Color, label: String, value: Double, unit: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatValue(value))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CadreColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - View modifier

/// Wires `chartXSelection` for the long-press-then-drag crosshair plus
/// the haptic tick that fires when the snapped day under the finger
/// changes. Horizontal scrolling (#62) was attempted alongside this and
/// reverted — see PR #71 — because Swift Charts' interaction between
/// `chartScrollableAxes` and `chartXSelection.annotation(position: .top)`
/// suppresses the callout and the default `.automatic` x-axis marks. To
/// be reattempted as a separate, deliberate UX pass.
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
/// the array is empty.
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

