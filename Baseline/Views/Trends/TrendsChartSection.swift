import SwiftUI
import Charts

/// The inline Trends chart experience: hero (latest / inspected value), the
/// Swift Charts plot with its draw-on reveal and drag-to-inspect crosshair,
/// the moving-average legend, the stats row, and the goal card. Owns the
/// inline crosshair selection and chart-reveal animation state.
///
/// Renders the full variant (2+ points), the single-point variant, or the
/// stepped-back empty-window placeholder. The cold-start empty state lives in
/// `TrendsView` (it has no chart/hero). The fullscreen chart is separate
/// (`TrendsFullscreenChart`); this view reports the expand tap via `onExpand`.
struct TrendsChartSection: View {
    let vm: TrendsViewModel?
    let goalVM: GoalViewModel?
    let compareEnabled: Bool
    let secondaryMetric: TrendMetric?
    let previousPeriod: PreviousPeriodType?
    let secondaryColor: Color
    let onExpand: () -> Void
    let onSetGoal: () -> Void
    let onManageGoal: () -> Void

    /// Selected date under the user's finger while long-press-then-drag is
    /// active (#63). `nil` means no crosshair drawn.
    @State private var inlineSelectedDate: Date?
    /// 0 → 1 reveal for the chart's draw-on animation (left-to-right plot mask).
    @State private var chartRevealProgress: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var selectedMetric: TrendMetric {
        vm?.selectedMetric ?? .weight
    }

    var body: some View {
        let points = vm?.dataPoints ?? []

        if points.isEmpty {
            // Caller only renders this view when some data exists; an empty
            // window with a prior latest point is the "stepped back" state.
            if let latest = vm?.latestPoint {
                steppedBackEmptyBlock(latest: latest)
            }
        } else if points.count == 1 {
            singlePointBlock(points: points)
        } else {
            fullBlock(points: points)
        }
    }

    // MARK: - Hero + window stepper

    /// Lay a hero out with its subtitle and the window stepper sharing one row
    /// beneath the values — subtitle on the left, stepper on the right. Keeps
    /// the hero to two rows and gives the stepper horizontal room instead of
    /// crowding the (wider) dual-hero in compare mode. On `.all` the stepper is
    /// hidden but still reserves its slot so the chart doesn't shift.
    private func heroWithStepper<V: View>(subtitle: String, _ hero: V) -> some View {
        let hideStepper = (vm?.timeRange ?? .month) == .all
        let subtitleText = Text(subtitle)
            .font(CadreTypography.trendsHeroSub)
            .foregroundStyle(CadreColors.textTertiary)
        let stepper = TrendsWindowStepper(vm: vm, onStep: { inlineSelectedDate = nil })
            .opacity(hideStepper ? 0 : 1)
            .allowsHitTesting(!hideStepper)

        return VStack(alignment: .leading, spacing: 8) {
            hero
            // Subtitle + stepper share one row at normal text sizes. At
            // accessibility Dynamic Type sizes they stack vertically so each
            // gets the full width to grow — squeezing them onto one row there
            // would constrain the text and prevent it from scaling.
            if dynamicTypeSize.isAccessibilitySize {
                subtitleText
                stepper.frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(spacing: 8) {
                    subtitleText
                    Spacer(minLength: 8)
                    stepper
                }
            }
        }
    }

    // MARK: - Full variant (2+ data points)

    private func fullBlock(points: [TrendDataPoint]) -> some View {
        let unit = selectedMetric.unit
        let latestValue = points.last?.value ?? 0
        let delta = (points.last?.value ?? 0) - (points.first?.value ?? 0)
        let periodSub = TrendsFormatting.periodSubtitle(points: points, unit: unit)
        let ma = vm?.movingAverage ?? []

        let secondaryPoints = vm?.secondaryDataPoints ?? []

        // Inspect mode (#63): when the user is dragging on the chart,
        // `inlineSelectedDate` becomes non-nil. Snap to the nearest data
        // point on each series and swap the hero block to show that
        // point's date + value(s) — Whoop-style live readout. Beats a
        // floating callout because it's always-visible and avoids the
        // chart-annotation overflow/clipping issues entirely.
        let snappedPrimary: TrendDataPoint? = inlineSelectedDate.flatMap {
            nearestPoint(to: $0, in: points)
        }
        let snappedSecondary: TrendDataPoint? = inlineSelectedDate.flatMap {
            nearestPoint(to: $0, in: secondaryPoints)
        }
        let inspecting = snappedPrimary != nil

        return VStack(spacing: 0) {
            if inspecting, let snap = snappedPrimary {
                if compareEnabled, let secMetric = secondaryMetric, let snapSec = snappedSecondary {
                    heroWithStepper(
                        subtitle: "",
                        inspectDualHero(
                            primaryValue: snap.value,
                            primaryUnit: unit,
                            primaryLabel: selectedMetric.displayName,
                            primaryDate: snap.date,
                            secondaryValue: snapSec.value,
                            secondaryUnit: secMetric.unit,
                            secondaryLabel: secMetric.displayName,
                            secondaryDate: snapSec.date
                        )
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 16)
                } else if compareEnabled, let period = previousPeriod, let snapSec = snappedSecondary {
                    heroWithStepper(
                        subtitle: "",
                        inspectDualHero(
                            primaryValue: snap.value,
                            primaryUnit: unit,
                            primaryLabel: "Current",
                            primaryDate: snap.date,
                            secondaryValue: snapSec.value,
                            secondaryUnit: unit,
                            secondaryLabel: period.rawValue,
                            secondaryDate: snapSec.date
                        )
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 16)
                } else {
                    heroWithStepper(
                        subtitle: DateFormatting.weekdayShort(snap.date),
                        inspectHero(value: snap.value, unit: unit)
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 20)
                }
            } else if compareEnabled, let secMetric = secondaryMetric, !secondaryPoints.isEmpty {
                heroWithStepper(
                    subtitle: periodSub,
                    dualHeroBlock(
                        primaryValue: latestValue,
                        primaryUnit: unit,
                        primaryLabel: selectedMetric.displayName,
                        secondaryValue: secondaryPoints.last?.value ?? 0,
                        secondaryUnit: secMetric.unit,
                        secondaryLabel: secMetric.displayName
                    )
                )
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 16)
            } else if compareEnabled, let period = previousPeriod, !secondaryPoints.isEmpty {
                heroWithStepper(
                    subtitle: periodSub,
                    dualHeroBlock(
                        primaryValue: latestValue,
                        primaryUnit: unit,
                        primaryLabel: "Current",
                        secondaryValue: secondaryPoints.last?.value ?? 0,
                        secondaryUnit: unit,
                        secondaryLabel: period.rawValue
                    )
                )
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 16)
            } else {
                heroWithStepper(
                    subtitle: periodSub,
                    heroBlock(latestValue: latestValue, unit: unit, delta: delta)
                )
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 20)
            }

            chartBlock(points: points, movingAverage: ma)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 18)

            if !ma.isEmpty {
                legendBlock
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 12)
            }

            GoalCard(
                goal: goalVM?.activeGoal(for: vm?.selectedMetric.rawValue ?? ""),
                currentValue: points.last?.value,
                unit: unit,
                onSetGoal: { onSetGoal() },
                onManageGoal: { onManageGoal() }
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 16)
        }
    }

    // MARK: - Hero (latest value)

    private func heroBlock(latestValue: Double, unit: String, delta: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(TrendsFormatting.value(latestValue))
                .font(CadreTypography.trendsHero)
                .tracking(-1.2)
                .foregroundStyle(CadreColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: latestValue)
                // Identifier lets the accessibility audit handler suppress the
                // dynamicTypeTextSizesNotSupported false-positive: this font is
                // built with UIFontMetrics and DOES scale at runtime — the XCTest
                // audit simply cannot detect UIFont-bridged scaling.
                .accessibilityIdentifier(A11yID.Trends.heroValue)
                // Explicit label combining value and unit prevents "label not
                // human-readable" audit failure for a purely numeric string.
                .accessibilityLabel(unit.isEmpty
                    ? "\(selectedMetric.displayName): \(TrendsFormatting.value(latestValue))"
                    : "\(selectedMetric.displayName): \(TrendsFormatting.value(latestValue)) \(unit)")
            if !unit.isEmpty {
                Text(unit)
                    .font(CadreTypography.trendsHeroUnit)
                    .foregroundStyle(CadreColors.textSecondary)
                    // Unit label is part of the heroValue combined label; hide
                    // from VoiceOver to avoid reading it twice.
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dualHeroBlock(
        primaryValue: Double,
        primaryUnit: String,
        primaryLabel: String,
        secondaryValue: Double,
        secondaryUnit: String,
        secondaryLabel: String
    ) -> some View {
        HStack(spacing: 22) {
            // Primary
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(CadreColors.accent)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(TrendsFormatting.value(primaryValue))
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(CadreColors.accent)
                        .contentTransition(.numericText())
                    if !primaryUnit.isEmpty {
                        Text(primaryUnit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
            }
            // Secondary
            VStack(alignment: .leading, spacing: 4) {
                Text(secondaryLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(secondaryColor)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(TrendsFormatting.value(secondaryValue))
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(secondaryColor)
                        .contentTransition(.numericText())
                    if !secondaryUnit.isEmpty {
                        Text(secondaryUnit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Compare-mode inspect hero. Each column carries its own snapped
    /// date because the two series can have different sampling cadences
    /// (daily weight vs monthly InBody scans), so the closest point on
    /// each series may fall on different dates — pretending they share
    /// one date would be misleading.
    private func inspectDualHero(
        primaryValue: Double,
        primaryUnit: String,
        primaryLabel: String,
        primaryDate: Date,
        secondaryValue: Double,
        secondaryUnit: String,
        secondaryLabel: String,
        secondaryDate: Date
    ) -> some View {
        HStack(alignment: .top, spacing: 22) {
            inspectHeroColumn(
                color: CadreColors.accent,
                label: primaryLabel,
                value: primaryValue,
                unit: primaryUnit,
                date: primaryDate
            )
            inspectHeroColumn(
                color: secondaryColor,
                label: secondaryLabel,
                value: secondaryValue,
                unit: secondaryUnit,
                date: secondaryDate
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inspectHeroColumn(color: Color, label: String, value: Double, unit: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(TrendsFormatting.value(value))
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            Text(DateFormatting.weekdayShort(date))
                .font(CadreTypography.trendsHeroSub)
                .foregroundStyle(CadreColors.textTertiary)
        }
    }

    /// Hero variant used while the user is scrubbing the chart (#63). Shows
    /// the snapped point's value in place of the latest; the snapped date is
    /// supplied as the subtitle by `heroWithStepper`. Same visual weight as
    /// `heroBlock` so the swap doesn't shift layout.
    private func inspectHero(value: Double, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(TrendsFormatting.value(value))
                .font(CadreTypography.trendsHero)
                .tracking(-1.2)
                .foregroundStyle(CadreColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
            if !unit.isEmpty {
                Text(unit)
                    .font(CadreTypography.trendsHeroUnit)
                    .foregroundStyle(CadreColors.textSecondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroRelativeDate(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let cal = calendar
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        if days < 7 { return "\(days) days ago" }
        return DateFormatting.shortDay(date)
    }

    // MARK: - Dual-axis helper

    /// Whether dual-axis normalization is needed (compare active with a different metric).
    /// Previous period uses the same scale, so no normalization needed.
    private var needsDualAxis: Bool {
        guard compareEnabled, secondaryMetric != nil else { return false }
        let secPoints = vm?.secondaryDataPoints ?? []
        guard !secPoints.isEmpty else { return false }
        // Previous period compare is same metric → same scale → no dual axis
        if previousPeriod != nil { return false }
        return true
    }

    // MARK: - Chart (Swift Charts)

    private func chartBlock(points: [TrendDataPoint], movingAverage: [MovingAveragePoint]) -> some View {
        let secondaryPoints = vm?.secondaryDataPoints ?? []
        let dualAxis = needsDualAxis
        let hasPreviousPeriod = previousPeriod != nil && compareEnabled && !secondaryPoints.isEmpty

        // Primary range (add 5% padding)
        let pMin = vm?.minValue ?? 0
        let pMax = vm?.maxValue ?? 0

        // Secondary range
        let sMin = vm?.secondaryMinValue ?? 0
        let sMax = vm?.secondaryMaxValue ?? 0

        // Include goal target value in the primary range so the goal line is always visible
        let goalTarget: Double? = goalVM?.activeGoal(for: vm?.selectedMetric.rawValue ?? "")?.targetValue
        let rangeMin = goalTarget.map { Swift.min(pMin, $0) } ?? pMin
        let rangeMax = goalTarget.map { Swift.max(pMax, $0) } ?? pMax

        // For previous period: merge both ranges since they share the same scale
        let effectiveMin = hasPreviousPeriod ? Swift.min(rangeMin, sMin) : rangeMin
        let effectiveMax = hasPreviousPeriod ? Swift.max(rangeMax, sMax) : rangeMax
        let pPad = max((effectiveMax - effectiveMin) * 0.05, 0.1)
        let primaryMin = effectiveMin - pPad
        let primaryMax = effectiveMax + pPad

        let sPad = max((sMax - sMin) * 0.05, 0.1)
        let secMin = sMin - sPad
        let secMax = sMax + sPad

        let crosshairCtx = CrosshairContext(
            primaryPoints: points,
            secondaryPoints: secondaryPoints,
            secondaryColor: secondaryColor,
            isDualAxis: dualAxis,
            primaryRange: primaryMin...primaryMax,
            secondaryRange: secMin...secMax
        )

        let showRawLine = vm?.showRawLine ?? true
        let showRawDots = vm?.showRawDots ?? true

        let chart = Chart {
            if showRawLine {
                ForEach(points) { point in
                    let yVal = dualAxis
                        ? TrendsAxisScale.normalize(point.value, min: primaryMin, max: primaryMax)
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
            if showRawDots {
                ForEach(points) { point in
                    let yVal = dualAxis
                        ? TrendsAxisScale.normalize(point.value, min: primaryMin, max: primaryMax)
                        : point.value
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", yVal)
                    )
                    .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                    .symbolSize(10)
                }
            }
            ForEach(movingAverage) { point in
                let yVal = dualAxis
                    ? TrendsAxisScale.normalize(point.value, min: primaryMin, max: primaryMax)
                    : point.value
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("MA", yVal),
                    series: .value("Series", "ma")
                )
                .foregroundStyle(CadreColors.chartLine)
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }

            // Secondary metric (compare mode)
            if compareEnabled && !secondaryPoints.isEmpty {
                ForEach(secondaryPoints) { point in
                    let yVal = dualAxis ? TrendsAxisScale.normalize(point.value, min: secMin, max: secMax) : point.value
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", yVal)
                    )
                    .foregroundStyle(secondaryColor)
                    .symbolSize(30)
                }
                ForEach(secondaryPoints) { point in
                    let yVal = dualAxis ? TrendsAxisScale.normalize(point.value, min: secMin, max: secMax) : point.value
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", yVal),
                        series: .value("Series", "secondary")
                    )
                    .foregroundStyle(secondaryColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [4, 3]))
                }
            }

            // Goal line — dotted horizontal at target value (primary chart only)
            if !dualAxis,
               let goal = goalVM?.activeGoal(for: vm?.selectedMetric.rawValue ?? "") {
                RuleMark(y: .value("Goal", goal.targetValue))
                    .foregroundStyle(CadreColors.accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .annotation(position: .trailing, alignment: .trailing) {
                        Text(TrendsFormatting.goalLabel(goal.targetValue, unit: vm?.selectedMetric.unit ?? ""))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(CadreColors.accent)
                            .padding(.leading, 4)
                    }
            }

            // Crosshair (#63) — vertical rule + highlighted point + callout.
            // No-op when `inlineSelectedDate` is nil so the chart renders
            // cleanly on first appear and after the user lifts their finger.
            crosshairMarks(selectedDate: inlineSelectedDate, context: crosshairCtx)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel()
                    .foregroundStyle(CadreColors.textTertiary)
                    .font(CadreTypography.trendsAxisLabel)
            }
        }
        .chartYAxis {
            if dualAxis {
                // Right axis: primary metric real values (stays on trailing like single-metric)
                let primaryTicks = TrendsAxisScale.axisTickValues(min: primaryMin, max: primaryMax)
                    .map { TrendsAxisScale.normalize($0, min: primaryMin, max: primaryMax) }
                AxisMarks(position: .trailing, values: primaryTicks) { mark in
                    AxisGridLine()
                        .foregroundStyle(CadreColors.chartGrid)
                    AxisValueLabel {
                        let norm = mark.as(Double.self) ?? 0
                        let real = primaryMin + norm * (primaryMax - primaryMin)
                        Text(TrendsFormatting.value(real))
                            .foregroundStyle(CadreColors.accent)
                            .font(CadreTypography.trendsAxisLabel)
                    }
                }
                // Left axis: secondary metric real values
                let secTicks = TrendsAxisScale.axisTickValues(min: secMin, max: secMax)
                    .map { TrendsAxisScale.normalize($0, min: secMin, max: secMax) }
                AxisMarks(position: .leading, values: secTicks) { mark in
                    AxisValueLabel {
                        let norm = mark.as(Double.self) ?? 0
                        let real = secMin + norm * (secMax - secMin)
                        Text(TrendsFormatting.value(real))
                            .foregroundStyle(secondaryColor)
                            .font(CadreTypography.trendsAxisLabel)
                    }
                }
            } else {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(CadreColors.chartGrid)
                    AxisValueLabel()
                        .foregroundStyle(CadreColors.textTertiary)
                        .font(CadreTypography.trendsAxisLabel)
                }
            }
        }
        .chartYScale(domain: dualAxis ? 0.0...1.0 : (primaryMin)...(primaryMax))
        .trendsChartInteractivity(selectedDate: $inlineSelectedDate)
        .chartPlotStyle { plotArea in
            plotArea
                .mask(alignment: .leading) {
                    // Rectangle's frame(width:) is animatable; LinearGradient
                    // stops aren't. So the reveal edge is driven by the
                    // rectangle, and a gradient strip rides its trailing
                    // edge to soften the cut into a "pencil tip." The strip's
                    // opacity tapers to 0 near the end so the final rendered
                    // state is fully crisp (no residual faded band).
                    GeometryReader { geo in
                        let revealW = geo.size.width * chartRevealProgress
                        // Fade band width as fraction of chart width. 0.20
                        // is very visible so the soft edge is obvious while
                        // tuning; drop toward 0.06 once it reads right.
                        let fadeW = geo.size.width * 0.20
                        let fadeOpacity = 1 - max(0, (chartRevealProgress - 0.80) / 0.20)
                        Rectangle()
                            .fill(.black)
                            .frame(width: revealW)
                            .overlay(alignment: .trailing) {
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: fadeW)
                                .opacity(fadeOpacity)
                                .allowsHitTesting(false)
                            }
                    }
                }
        }
        .frame(height: 280)
        .overlay(alignment: .topTrailing) {
            expandStub
                .padding(8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(selectedMetric.displayName) trend chart with \(points.count) data points")
        // Suppress Charts' built-in morph between datasets. Without this,
        // switching from 30 → 180 points produced a chaotic flash of
        // interpolated lines as the two LineMarks tried to tween into
        // each other. Scoped to these two values, so our mask reveal
        // (driven by chartRevealProgress) is unaffected.
        .animation(nil, value: vm?.timeRange)
        .animation(nil, value: vm?.selectedMetric)
        .onAppear {
            triggerChartReveal()
            inlineSelectedDate = nil
        }
        .onChange(of: vm?.timeRange) { _, _ in
            triggerChartReveal()
            inlineSelectedDate = nil
        }
        .onChange(of: vm?.selectedMetric) { _, _ in
            triggerChartReveal()
            inlineSelectedDate = nil
            // New metric should open on its most recent data, not at
            // wherever the user had stepped to in the previous metric.
            vm?.windowEndDate = Date()
        }
        .onChange(of: vm?.windowEndDate) { _, _ in
            // Re-run the reveal animation when the user steps to a new
            // window so the chart visibly redraws — same affordance as
            // changing the time range.
            triggerChartReveal()
        }

        return chart
    }

    /// Reset `chartRevealProgress` and animate it to 1 so the plot area
    /// draws in from left to right. Runs on first appear and whenever the
    /// user swaps metric or time range — those are the moments where the
    /// chart shows a different dataset and the reveal feels intentional,
    /// not noisy.
    private func triggerChartReveal() {
        // Skip the reveal under XCTest — snapshot tests capture the
        // hosting controller's first frame, before .onAppear's animation
        // can run. Without this guard, snapshots come out with a blank
        // chart area where the line should be.
        if reduceMotion || LaunchConfiguration.current.shouldDisableAnimations {
            chartRevealProgress = 1
            return
        }
        chartRevealProgress = 0
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.0)) {
                chartRevealProgress = 1
            }
        }
    }

    private var expandStub: some View {
        Button {
            onExpand()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CadreColors.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(CadreColors.divider.opacity(0.7))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Legend

    private var legendBlock: some View {
        HStack(spacing: 14) {
            if compareEnabled, let sec = secondaryMetric {
                legendItem(color: CadreColors.accent, label: selectedMetric.displayName)
                legendItem(color: secondaryColor, label: sec.displayName, dashed: true)
            } else if compareEnabled, let period = previousPeriod {
                legendItem(color: CadreColors.accent, label: "Current")
                legendItem(color: secondaryColor, label: period.rawValue, dashed: true)
            } else {
                if vm?.showRawLine == true || vm?.showRawDots == true {
                    legendItem(color: CadreColors.textTertiary, label: "Daily")
                }
                legendItem(color: CadreColors.chartLine, label: "\(vm?.movingAverageWindow ?? 7)-day average")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            if dashed {
                // Decorative dashed-line indicator — hidden from accessibility
                // tree to prevent "label not human-readable" audit failures on
                // unlabeled shape elements.
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color)
                            .frame(width: 3, height: 2)
                    }
                }
                .frame(width: 12)
                .accessibilityHidden(true)
            } else {
                // Decorative solid-line indicator — hidden from accessibility tree.
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 12, height: 2)
                    .accessibilityHidden(true)
            }
            // lineLimit(1) prevents text from wrapping or overflowing the
            // containing VStack, which could cause the audit to flag "text clipped"
            // if the text extends past the screen/NavigationStack safe area bounds.
            Text(label)
                .font(CadreTypography.trendsLegend)
                .foregroundStyle(CadreColors.textSecondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Stats row (Start / Lowest / Current)

    private func statsBlock(points: [TrendDataPoint], unit: String) -> some View {
        let start = points.first?.value
        let current = points.last?.value
        let lowest = points.map(\.value).min()

        return HStack(spacing: 1) {
            statCell(label: "START", value: start, unit: unit)
            statCell(label: "LOWEST", value: lowest, unit: unit)
            statCell(label: "CURRENT", value: current, unit: unit)
        }
        .background(CadreColors.divider)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(label: String, value: Double?, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(CadreTypography.trendsStatLabel)
                .tracking(0.5)
                .foregroundStyle(CadreColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.map { TrendsFormatting.value($0) } ?? "\u{2014}")
                    .font(CadreTypography.trendsStatValue)
                    .foregroundStyle(CadreColors.textPrimary)
                    .contentTransition(.numericText())
                if value != nil && !unit.isEmpty {
                    Text(unit)
                        .font(CadreTypography.trendsStatUnit)
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .background(CadreColors.card)
    }

    // MARK: - Single-point variant

    private func singlePointBlock(points: [TrendDataPoint]) -> some View {
        let point = points[0]
        let unit = selectedMetric.unit
        return VStack(spacing: 0) {
            heroWithStepper(
                subtitle: "Log more entries to see your trend",
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TrendsFormatting.value(point.value))
                        .font(CadreTypography.trendsHero)
                        .tracking(-1.2)
                        .foregroundStyle(CadreColors.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(CadreTypography.trendsHeroUnit)
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 20)

            singlePointChart(point: point)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 14)

            GoalCard(
                goal: goalVM?.activeGoal(for: vm?.selectedMetric.rawValue ?? ""),
                currentValue: points.last?.value,
                unit: unit,
                onSetGoal: { onSetGoal() },
                onManageGoal: { onManageGoal() }
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 12)
        }
    }

    private func singlePointChart(point: TrendDataPoint) -> some View {
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
        .frame(height: 280)
        .overlay(alignment: .topTrailing) {
            expandStub
                .padding(8)
        }
    }

    // MARK: - Empty state

    /// Shown when the active window has no data but the user *does* have
    /// data overall (i.e., they've stepped back into an empty range). The
    /// chart placeholder explains the state and the stepper above it lets
    /// them step forward to where the data lives. The hero + goal still
    /// render — they're about the user's overall state, not just this
    /// window — so the screen doesn't feel like an unrelated cold-start.
    private func steppedBackEmptyBlock(latest: TrendDataPoint) -> some View {
        let unit = selectedMetric.unit
        return VStack(spacing: 0) {
            heroWithStepper(
                subtitle: heroRelativeDate(from: latest.date),
                inspectHero(value: latest.value, unit: unit)
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 20)

            VStack(spacing: 8) {
                Image(systemName: "chart.line.flattrend.xyaxis")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(CadreColors.textTertiary)
                Text("No data in this window")
                    .font(CadreTypography.trendsHeroSub)
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 18)

            GoalCard(
                goal: goalVM?.activeGoal(for: vm?.selectedMetric.rawValue ?? ""),
                currentValue: latest.value,
                unit: unit,
                onSetGoal: { onSetGoal() },
                onManageGoal: { onManageGoal() }
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 16)
        }
    }
}
