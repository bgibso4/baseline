import SwiftUI
import Charts

/// Landscape, two-column fullscreen chart presented from the Trends tab's
/// expand button. Left column shows the metric hero(s); the right fills with
/// the chart. Owns its own crosshair selection (`fullscreenSelectedDate`),
/// separate from the inline chart's selection.
struct TrendsFullscreenChart: View {
    let vm: TrendsViewModel?
    let compareEnabled: Bool
    let secondaryMetric: TrendMetric?
    let previousPeriod: PreviousPeriodType?
    let secondaryColor: Color
    let onClose: () -> Void

    @State private var fullscreenSelectedDate: Date?

    private var selectedMetric: TrendMetric {
        vm?.selectedMetric ?? .weight
    }

    /// Centered window stepper, hidden (but space-reserved) on the `.all`
    /// range. Shown in every data state — including an empty or single-point
    /// window — so stepping back out to where data lives stays possible.
    private var fsStepperRow: some View {
        let hideStepper = (vm?.timeRange ?? .month) == .all
        return HStack {
            Spacer()
            TrendsWindowStepper(vm: vm, onStep: { fullscreenSelectedDate = nil })
            Spacer()
        }
        .opacity(hideStepper ? 0 : 1)
        .allowsHitTesting(!hideStepper)
        // Keep clear of the close button, which overlays the top-right corner.
        .padding(.trailing, 36)
    }

    var body: some View {
        let points = vm?.dataPoints ?? []
        let ma = vm?.movingAverage ?? []
        let secondaryPoints = vm?.secondaryDataPoints ?? []
        let unit = selectedMetric.unit
        let latestValue = points.last?.value ?? 0
        let periodSub = TrendsFormatting.periodSubtitle(points: points, unit: unit)
        let hasSecondary = compareEnabled && secondaryMetric != nil && !secondaryPoints.isEmpty

        // Inspect mode: when the user drags the crosshair, snap the left-panel
        // hero(s) to the nearest point and show that point's date — parity with
        // the portrait chart, which swaps to an inspect hero on drag.
        let snappedPrimary = fullscreenSelectedDate.flatMap { nearestPoint(to: $0, in: points) }
        let snappedSecondary = fullscreenSelectedDate.flatMap { nearestPoint(to: $0, in: secondaryPoints) }
        let primaryValue = snappedPrimary?.value ?? latestValue
        let secondaryValue = snappedSecondary?.value ?? (secondaryPoints.last?.value ?? 0)
        let heroSubtitle = snappedPrimary.map { DateFormatting.weekdayShort($0.date) } ?? periodSub

        return ZStack {
            GradientBackground(center: .top)

            HStack(spacing: 0) {
                // Left panel: metric info
                VStack(alignment: .leading, spacing: 12) {
                    if hasSecondary, let secMetric = secondaryMetric {
                        // Dual hero for compare mode
                        // Primary
                        HStack(spacing: 8) {
                            Circle().fill(CadreColors.accent).frame(width: 8, height: 8)
                            Text(selectedMetric.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CadreColors.textPrimary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(TrendsFormatting.value(primaryValue))
                                .font(.system(size: 32, weight: .bold))
                                .tracking(-0.8)
                                .foregroundStyle(CadreColors.accent)
                            if !unit.isEmpty {
                                Text(unit)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(CadreColors.textSecondary)
                            }
                        }

                        // Divider
                        Rectangle().fill(CadreColors.divider).frame(height: 0.5)

                        // Secondary
                        HStack(spacing: 8) {
                            Circle().fill(secondaryColor).frame(width: 8, height: 8)
                            Text(secMetric.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CadreColors.textPrimary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(TrendsFormatting.value(secondaryValue))
                                .font(.system(size: 32, weight: .bold))
                                .tracking(-0.8)
                                .foregroundStyle(secondaryColor)
                            if !secMetric.unit.isEmpty {
                                Text(secMetric.unit)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(CadreColors.textSecondary)
                            }
                        }
                    } else {
                        // Single metric hero
                        HStack(spacing: 8) {
                            Circle().fill(CadreColors.accent).frame(width: 8, height: 8)
                            Text(selectedMetric.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CadreColors.textPrimary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(TrendsFormatting.value(primaryValue))
                                .font(.system(size: 36, weight: .bold))
                                .tracking(-1.0)
                                .foregroundStyle(CadreColors.accent)
                            if !unit.isEmpty {
                                Text(unit)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CadreColors.textSecondary)
                            }
                        }
                    }

                    Text(heroSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)

                    Spacer()
                }
                .frame(width: 180)
                .padding()

                // Right: chart fills remaining space
                if points.count >= 2 {
                    let fsDualAxis = hasSecondary && previousPeriod == nil
                    let fsHasPreviousPeriod = previousPeriod != nil && hasSecondary
                    let fsPMin = vm?.minValue ?? 0
                    let fsPMax = vm?.maxValue ?? 0
                    let fsSMin = vm?.secondaryMinValue ?? 0
                    let fsSMax = vm?.secondaryMaxValue ?? 0
                    let fsEffMin = fsHasPreviousPeriod ? Swift.min(fsPMin, fsSMin) : fsPMin
                    let fsEffMax = fsHasPreviousPeriod ? Swift.max(fsPMax, fsSMax) : fsPMax
                    let fsPPad = max((fsEffMax - fsEffMin) * 0.05, 0.1)
                    let fsPrimaryMin = fsEffMin - fsPPad
                    let fsPrimaryMax = fsEffMax + fsPPad
                    let fsSPad = max((fsSMax - fsSMin) * 0.05, 0.1)
                    let fsSecMin = fsSMin - fsSPad
                    let fsSecMax = fsSMax + fsSPad

                    let fsCrosshairCtx = CrosshairContext(
                        primaryPoints: points,
                        secondaryPoints: secondaryPoints,
                        secondaryColor: secondaryColor,
                        isDualAxis: fsDualAxis,
                        primaryRange: fsPrimaryMin...fsPrimaryMax,
                        secondaryRange: fsSecMin...fsSecMax
                    )

                    let fsShowRawLine = vm?.showRawLine ?? true
                    let fsShowRawDots = vm?.showRawDots ?? true

                    VStack(spacing: 6) {
                        fsStepperRow

                        Chart {
                        if fsShowRawLine {
                            ForEach(points) { point in
                                let yVal = fsDualAxis
                                    ? TrendsAxisScale.normalize(point.value, min: fsPrimaryMin, max: fsPrimaryMax)
                                    : point.value
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", yVal),
                                    series: .value("Series", "raw")
                                )
                                .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                            }
                        }
                        if fsShowRawDots {
                            ForEach(points) { point in
                                let yVal = fsDualAxis
                                    ? TrendsAxisScale.normalize(point.value, min: fsPrimaryMin, max: fsPrimaryMax)
                                    : point.value
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", yVal)
                                )
                                .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                                .symbolSize(10)
                            }
                        }
                        ForEach(ma) { point in
                            let yVal = fsDualAxis
                                ? TrendsAxisScale.normalize(point.value, min: fsPrimaryMin, max: fsPrimaryMax)
                                : point.value
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("MA", yVal),
                                series: .value("Series", "ma")
                            )
                            .foregroundStyle(CadreColors.chartLine)
                            .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        }

                        // Secondary metric line (compare)
                        if hasSecondary {
                            ForEach(secondaryPoints) { point in
                                let yVal = fsDualAxis
                                    ? TrendsAxisScale.normalize(point.value, min: fsSecMin, max: fsSecMax) : point.value
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", yVal)
                                )
                                .foregroundStyle(secondaryColor)
                                .symbolSize(30)
                            }
                            ForEach(secondaryPoints) { point in
                                let yVal = fsDualAxis
                                    ? TrendsAxisScale.normalize(point.value, min: fsSecMin, max: fsSecMax) : point.value
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", yVal),
                                    series: .value("Series", "secondary")
                                )
                                .foregroundStyle(secondaryColor)
                                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [4, 3]))
                            }
                        }

                        crosshairMarks(selectedDate: fullscreenSelectedDate, context: fsCrosshairCtx)
                        }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisValueLabel()
                                .foregroundStyle(CadreColors.textTertiary)
                                .font(CadreTypography.trendsAxisLabel)
                        }
                    }
                    .chartYAxis {
                        if fsDualAxis {
                            let fsPrimaryTicks = TrendsAxisScale.axisTickValues(min: fsPrimaryMin, max: fsPrimaryMax)
                                .map { TrendsAxisScale.normalize($0, min: fsPrimaryMin, max: fsPrimaryMax) }
                            AxisMarks(position: .trailing, values: fsPrimaryTicks) { mark in
                                AxisGridLine()
                                    .foregroundStyle(CadreColors.chartGrid)
                                AxisValueLabel {
                                    let norm = mark.as(Double.self) ?? 0
                                    let real = fsPrimaryMin + norm * (fsPrimaryMax - fsPrimaryMin)
                                    Text(TrendsFormatting.value(real))
                                        .foregroundStyle(CadreColors.accent)
                                        .font(CadreTypography.trendsAxisLabel)
                                }
                            }
                            let fsSecTicks = TrendsAxisScale.axisTickValues(min: fsSecMin, max: fsSecMax)
                                .map { TrendsAxisScale.normalize($0, min: fsSecMin, max: fsSecMax) }
                            AxisMarks(position: .leading, values: fsSecTicks) { mark in
                                AxisValueLabel {
                                    let norm = mark.as(Double.self) ?? 0
                                    let real = fsSecMin + norm * (fsSecMax - fsSecMin)
                                    Text(TrendsFormatting.value(real))
                                        .foregroundStyle(secondaryColor)
                                        .font(CadreTypography.trendsAxisLabel)
                                }
                            }
                        } else {
                            AxisMarks(position: .trailing, values: .automatic(desiredCount: 6)) { _ in
                                AxisGridLine()
                                    .foregroundStyle(CadreColors.chartGrid)
                                AxisValueLabel()
                                    .foregroundStyle(CadreColors.textTertiary)
                                    .font(CadreTypography.trendsAxisLabel)
                            }
                        }
                    }
                    .chartYScale(domain: fsDualAxis ? 0.0...1.0 : (fsPrimaryMin)...(fsPrimaryMax))
                    .trendsChartInteractivity(selectedDate: $fullscreenSelectedDate)
                    }
                    .padding()
                    .onAppear { fullscreenSelectedDate = nil }
                } else if let point = points.first {
                    VStack(spacing: 6) {
                        fsStepperRow
                        Chart {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(CadreColors.chartLine)
                            .symbolSize(80)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartYScale(domain: (point.value - 2)...(point.value + 2))
                    }
                    .padding()
                } else {
                    VStack(spacing: 6) {
                        fsStepperRow
                        Spacer()
                        Text("No data")
                            .font(CadreTypography.trendsEmptyTitle)
                            .foregroundStyle(CadreColors.textTertiary)
                        Spacer()
                    }
                    .padding()
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(CadreColors.card)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
}
