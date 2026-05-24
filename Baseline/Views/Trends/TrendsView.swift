import SwiftUI
import SwiftData
import Charts
import TipKit

/// Trends tab — metric trend over selectable time range.
///
/// Visual target: `docs/mockups/trends-APPROVED-2026-04-05.html` (default
/// variant · "Weight + 7-day MA") and `docs/mockups/trends-edge-cases-2026-04-05.html`
/// (variants 01 zero-data, 02 single point, 03 sparse).
///
/// Layout: metric chip (overlay dropdown) → range tabs (M/6M/Y/All) → hero
/// (latest value) → chart (280pt, line + points + dashed 7-day MA) → legend →
/// stats row.
struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState: AppState?

    // Track unit preferences so SwiftUI re-renders when they change
    @AppStorage("weightUnit") private var weightUnit = "lb"
    @AppStorage("lengthUnit") private var lengthUnit = "in"

    @State private var vm: TrendsViewModel?
    @State private var goalVM: GoalViewModel?
    @State private var showSetGoal = false
    @State private var showManageGoal = false
    @State private var showEditGoal = false
    @State private var showMetricSheet = false
    @State private var compareEnabled = false
    @State private var secondaryMetric: TrendMetric?
    @State private var previousPeriod: PreviousPeriodType?
    @State private var availableMetrics: [TrendMetric] = TrendMetric.allCases
    @State private var showFullscreen = false

    /// 0 → 1 reveal for the main chart's draw-on animation. Drives a
    /// left-to-right mask on the plot area (axis stays visible). Reset
    /// and re-animated on first appear and on metric/range change so the
    /// user sees each new slice of data actually draw itself, rather
    /// than popping in.
    @State private var chartRevealProgress: Double = 0

    // MARK: - Chart interactivity (#63 — drag-to-inspect crosshair)

    /// Selected date under the user's finger when long-press-then-drag is
    /// active. `nil` means no crosshair drawn. Separate state for inline
    /// vs fullscreen so the two charts don't fight over the same selection.
    @State private var inlineSelectedDate: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Synchronous VM injection (snapshot / unit tests).
    private let injectedVM: TrendsViewModel?
    private let trendsTip = TrendsTip()

    init(viewModel: TrendsViewModel? = nil) {
        self.injectedVM = viewModel
        self._vm = State(initialValue: viewModel)
    }

    /// Seed the view's `@State` with a preloaded VM without marking it
    /// as "test-injected." Used by MainTabView at app launch so the first
    /// body render already has data — avoids the empty→populated reflow
    /// that was visible mid-tab-switch. Unlike `init(viewModel:)`, this
    /// does NOT set `injectedVM`, so the normal onAppear path (refresh,
    /// metric routing, availableMetrics, showSetGoalOnTrendsAppear) still
    /// runs.
    init(preloadedVM: TrendsViewModel?) {
        self.injectedVM = nil
        self._vm = State(initialValue: preloadedVM)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                GradientBackground(center: .top)

                VStack(spacing: 0) {
                    TrendsMetricChip(
                        selectedMetric: selectedMetric,
                        compareEnabled: compareEnabled,
                        secondaryMetric: secondaryMetric,
                        previousPeriod: previousPeriod,
                        secondaryColor: secondaryColor,
                        onTap: { showMetricSheet = true }
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, CadreSpacing.md)

                    TrendsRangeTabs(
                        selected: vm?.timeRange ?? .month,
                        onSelect: { range in
                            withAnimation(.snappy(duration: 0.25)) {
                                vm?.timeRange = range
                                // Reset the window anchor so the new range
                                // opens on the most recent slice of data, not
                                // wherever the user had stepped to in the
                                // previous range.
                                vm?.windowEndDate = Date()
                                inlineSelectedDate = nil
                                vm?.refresh()
                            }
                            Haptics.selection()
                        }
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 12)

                    TipView(trendsTip)
                        .padding(.horizontal, CadreSpacing.sheetHorizontal)
                        .padding(.top, 8)

                    content
                        .animation(.easeInOut(duration: 0.3), value: vm?.selectedMetric)
                        .animation(.easeInOut(duration: 0.3), value: vm?.timeRange)

                    Spacer(minLength: 0)
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showFullscreen) {
                LandscapeHostingController(content: TrendsFullscreenChart(
                    vm: vm,
                    compareEnabled: compareEnabled,
                    secondaryMetric: secondaryMetric,
                    previousPeriod: previousPeriod,
                    secondaryColor: secondaryColor,
                    onClose: { showFullscreen = false }
                ))
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showMetricSheet) {
                MetricPickerSheet(
                    selectedMetric: Binding(
                        get: { vm?.selectedMetric ?? .weight },
                        set: { vm?.selectedMetric = $0 }
                    ),
                    compareEnabled: $compareEnabled,
                    secondaryMetric: $secondaryMetric,
                    previousPeriod: $previousPeriod,
                    availableMetrics: availableMetrics,
                    onDismiss: { vm?.refresh() }
                )
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(red: 28 / 255, green: 28 / 255, blue: 34 / 255))
            }
            .sheet(isPresented: $showSetGoal) {
                if let goalVM {
                    SetGoalSheet(
                        goalVM: goalVM,
                        defaultMetric: vm?.selectedMetric ?? .weight,
                        currentValue: vm?.dataPoints.last?.value
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                }
            }
            .sheet(isPresented: $showManageGoal) {
                if let goalVM, let goal = goalVM.activeGoal(for: vm?.selectedMetric.rawValue ?? "") {
                    GoalManageSheet(
                        goal: goal,
                        currentValue: vm?.dataPoints.last?.value ?? 0,
                        unit: vm?.selectedMetric.unit ?? "",
                        onEdit: { showEditGoal = true },
                        onComplete: { goalVM.completeGoal(metric: goal.metric) },
                        onAbandon: { goalVM.abandonGoal(metric: goal.metric) }
                    )
                    .presentationDetents([.fraction(0.35)])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(CadreColors.card)
                }
            }
            .sheet(isPresented: $showEditGoal) {
                if let goalVM, let goal = goalVM.activeGoal(for: vm?.selectedMetric.rawValue ?? "") {
                    SetGoalSheet(
                        goalVM: goalVM,
                        defaultMetric: vm?.selectedMetric ?? .weight,
                        currentValue: vm?.dataPoints.last?.value,
                        editingGoal: goal
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                }
            }
            .onAppear {
                guard injectedVM == nil else { return }
                if vm == nil {
                    // Prefer MainTabView's preloaded VM so the first render
                    // already has data (no layout reflow mid tab-switch).
                    vm = (appState?.preloadedTrendsVM as? TrendsViewModel)
                        ?? TrendsViewModel(modelContext: modelContext)
                }
                if goalVM == nil {
                    goalVM = (appState?.preloadedGoalVM as? GoalViewModel)
                        ?? GoalViewModel(modelContext: modelContext)
                }
                // Pick up one-shot metric request from another tab (e.g. Body → Trends).
                // Clear after consuming so returning to Trends later preserves the
                // user's in-tab selection.
                if let metricName = appState?.trendMetric,
                   let metric = TrendMetric(rawValue: metricName) {
                    vm?.selectedMetric = metric
                    appState?.trendMetric = nil
                }
                vm?.refresh()
                availableMetrics = vm?.computeAvailableMetrics() ?? TrendMetric.allCases

                // Honour a pending request from NowView's goal-reached
                // overlay. Delay by one frame so the tab-switch animation
                // finishes before the sheet slides up over it.
                if appState?.showSetGoalOnTrendsAppear == true {
                    appState?.showSetGoalOnTrendsAppear = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        showSetGoal = true
                    }
                }
            }
            .onChange(of: appState?.trendMetric) { _, newValue in
                if let newValue, let metric = TrendMetric(rawValue: newValue) {
                    vm?.selectedMetric = metric
                    vm?.refresh()
                    appState?.trendMetric = nil
                }
            }
            .onChange(of: secondaryMetric) { _, newValue in
                vm?.secondaryMetric = newValue
                if let metric = newValue {
                    vm?.compareMode = .metric(metric)
                } else if previousPeriod == nil {
                    vm?.compareMode = nil
                }
                vm?.refresh()
            }
            .onChange(of: previousPeriod) { _, newValue in
                if let period = newValue {
                    vm?.compareMode = .previousPeriod(period)
                    vm?.secondaryMetric = nil
                } else if secondaryMetric == nil {
                    vm?.compareMode = nil
                }
                vm?.refresh()
            }
            .onChange(of: compareEnabled) { _, enabled in
                if !enabled {
                    secondaryMetric = nil
                    previousPeriod = nil
                    vm?.secondaryMetric = nil
                    vm?.compareMode = nil
                }
                vm?.refresh()
            }
            .onChange(of: weightUnit) { _, _ in vm?.refresh() }
            .onChange(of: lengthUnit) { _, _ in vm?.refresh() }
        }
    }

    // MARK: - Convenience

    private var selectedMetric: TrendMetric {
        vm?.selectedMetric ?? .weight
    }

    // MARK: - Body state machine

    @ViewBuilder
    private var content: some View {
        let points = vm?.dataPoints ?? []

        if points.isEmpty {
            // Distinguish "stepped-back into an empty window" from a real
            // cold-start: if any data exists for this metric, show the
            // window-empty placeholder (with stepper) instead of the
            // log-your-first-entry CTA.
            if let latest = vm?.latestPoint {
                steppedBackEmptyBlock(latest: latest)
            } else {
                TrendsEmptyState(
                    metric: selectedMetric,
                    onSelectTab: { appState?.selectedTab = $0 }
                )
            }
        } else if points.count == 1 {
            singlePointBlock(points: points)
        } else {
            fullBlock(points: points)
        }
    }

    // MARK: - Shared palette

    /// Dusty secondary accent used for the compare / secondary-metric series.
    /// Threaded into `TrendsMetricChip` and the chart/legend/hero rendering.
    private let secondaryColor = Color(hex: "B89968")

    // MARK: - Hero stepper overlay

    /// Pin the window stepper to the bottom-right edge of whatever hero
    /// view it's applied to. Uses an overlay so the hero's intrinsic
    /// layout (and thus the chart's vertical position) doesn't shift
    /// between time ranges. On `.all` the stepper is invisible and
    /// non-interactive but still occupies its slot.
    private func heroStepperOverlay<V: View>(_ hero: V) -> some View {
        let hideStepper = (vm?.timeRange ?? .month) == .all
        return hero
            .overlay(alignment: .bottomTrailing) {
                TrendsWindowStepper(vm: vm, onStep: { inlineSelectedDate = nil })
                    .opacity(hideStepper ? 0 : 1)
                    .allowsHitTesting(!hideStepper)
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
                    heroStepperOverlay(
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
                    heroStepperOverlay(
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
                    heroStepperOverlay(
                        inspectHero(value: snap.value, unit: unit, dateSub: DateFormatting.weekdayShort(snap.date))
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 20)
                }
            } else if compareEnabled, let secMetric = secondaryMetric, !secondaryPoints.isEmpty {
                heroStepperOverlay(
                    dualHeroBlock(
                        primaryValue: latestValue,
                        primaryUnit: unit,
                        primaryLabel: selectedMetric.displayName,
                        secondaryValue: secondaryPoints.last?.value ?? 0,
                        secondaryUnit: secMetric.unit,
                        secondaryLabel: secMetric.displayName,
                        sub: periodSub
                    )
                )
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 16)
            } else if compareEnabled, let period = previousPeriod, !secondaryPoints.isEmpty {
                heroStepperOverlay(
                    dualHeroBlock(
                        primaryValue: latestValue,
                        primaryUnit: unit,
                        primaryLabel: "Current",
                        secondaryValue: secondaryPoints.last?.value ?? 0,
                        secondaryUnit: unit,
                        secondaryLabel: period.rawValue,
                        sub: periodSub
                    )
                )
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 16)
            } else {
                heroStepperOverlay(
                    heroBlock(latestValue: latestValue, unit: unit, delta: delta, sub: periodSub)
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
                onSetGoal: { showSetGoal = true },
                onManageGoal: { showManageGoal = true }
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 16)
        }
    }

    // MARK: - Hero (latest value)

    private func heroBlock(latestValue: Double, unit: String, delta: Double, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

            // Per-period rate subtitle (e.g. "−0.8 lb / week"), shown for every
            // metric including weight. The date range is intentionally omitted —
            // it's already conveyed by the window stepper. Sparse windows (<7
            // entries) fall back to an entry count — see TrendsFormatting.
            Text(sub)
                .font(CadreTypography.trendsHeroSub)
                .foregroundStyle(CadreColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dualHeroBlock(
        primaryValue: Double,
        primaryUnit: String,
        primaryLabel: String,
        secondaryValue: Double,
        secondaryUnit: String,
        secondaryLabel: String,
        sub: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            Text(sub)
                .font(CadreTypography.trendsHeroSub)
                .foregroundStyle(CadreColors.textTertiary)
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
    /// the snapped point's value in place of the latest, with the snapped
    /// date as the sub-line ("Wed, Apr 3"). Same visual weight as
    /// `heroBlock` so the swap doesn't shift layout.
    private func inspectHero(value: Double, unit: String, dateSub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text(dateSub)
                .font(CadreTypography.trendsHeroSub)
                .foregroundStyle(CadreColors.textTertiary)
        }
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
            showFullscreen = true
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
            heroStepperOverlay(
                VStack(alignment: .leading, spacing: 8) {
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
                    Text("Log more entries to see your trend")
                        .font(CadreTypography.trendsHeroSub)
                        .foregroundStyle(CadreColors.textTertiary)
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
                onSetGoal: { showSetGoal = true },
                onManageGoal: { showManageGoal = true }
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
            heroStepperOverlay(
                inspectHero(value: latest.value, unit: unit, dateSub: heroRelativeDate(from: latest.date))
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
                onSetGoal: { showSetGoal = true },
                onManageGoal: { showManageGoal = true }
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 16)
        }
    }
}

#Preview {
    TrendsView()
        .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
}
