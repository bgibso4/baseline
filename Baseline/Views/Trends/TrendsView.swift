import SwiftUI
import SwiftData
import Charts
import TipKit
import UIKit

// MARK: - Landscape Hosting (forces landscape orientation for fullscreen chart)

private struct LandscapeHostingController<Content: View>: UIViewControllerRepresentable {
    let content: Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        LandscapeHostingVC(rootView: content)
    }

    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}

private class LandscapeHostingVC<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

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

    /// Synchronous VM injection (snapshot / unit tests).
    private let injectedVM: TrendsViewModel?
    private let trendsTip = TrendsTip()

    init(viewModel: TrendsViewModel? = nil) {
        self.injectedVM = viewModel
        self._vm = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CadreColors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    metricChipButton
                        .padding(.horizontal, CadreSpacing.sheetHorizontal)
                        .padding(.top, CadreSpacing.md)

                    rangeTabs
                        .padding(.horizontal, CadreSpacing.sheetHorizontal)
                        .padding(.top, 10)

                    TipView(trendsTip)
                        .padding(.horizontal, CadreSpacing.sheetHorizontal)
                        .padding(.top, 8)

                    content
                        .animation(.easeInOut(duration: 0.3), value: vm?.selectedMetric)
                        .animation(.easeInOut(duration: 0.3), value: vm?.timeRange)

                    Spacer(minLength: 0)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showFullscreen) {
                LandscapeHostingController(content: fullscreenChartContent)
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
                .presentationBackground(Color(red: 28/255, green: 28/255, blue: 34/255))
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
                    vm = TrendsViewModel(modelContext: modelContext)
                }
                if goalVM == nil {
                    goalVM = GoalViewModel(modelContext: modelContext)
                }
                // Pick up metric requested by another tab (e.g. Body → Trends)
                if let metricName = appState?.trendMetric,
                   let metric = TrendMetric(rawValue: metricName) {
                    vm?.selectedMetric = metric
                }
                vm?.refresh()
                availableMetrics = vm?.computeAvailableMetrics() ?? TrendMetric.allCases
            }
            .onChange(of: appState?.trendMetric) { _, newValue in
                if let newValue, let metric = TrendMetric(rawValue: newValue) {
                    vm?.selectedMetric = metric
                    vm?.refresh()
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
            emptyStateBlock
        } else if points.count == 1 {
            singlePointBlock(points: points)
        } else {
            fullBlock(points: points)
        }
    }

    // MARK: - Metric chip button (always visible)

    private let secondaryColor = Color(hex: "B89968") // dusty secondaryColor from design tokens

    private var metricChipButton: some View {
        Button {
            showMetricSheet = true
        } label: {
            HStack(spacing: 10) {
                if compareEnabled, let secondary = secondaryMetric {
                    // Dual-icon stack for metric compare
                    ZStack {
                        RoundedRectangle(cornerRadius: CadreRadius.sm)
                            .fill(CadreColors.cardElevated)
                            .frame(width: 28, height: 28)
                        Image(systemName: selectedMetric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.accent)
                            .offset(x: -3, y: -2)
                        Image(systemName: secondary.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(secondaryColor)
                            .offset(x: 5, y: 4)
                    }
                    Text("\(selectedMetric.rawValue) \u{00B7} \(secondary.rawValue)")
                        .font(CadreTypography.trendsMetricName)
                        .tracking(-0.1)
                        .foregroundStyle(CadreColors.textPrimary)
                        .lineLimit(1)
                } else if compareEnabled, let period = previousPeriod {
                    // Period compare chip
                    ZStack {
                        RoundedRectangle(cornerRadius: CadreRadius.sm)
                            .fill(CadreColors.cardElevated)
                            .frame(width: 28, height: 28)
                        Image(systemName: selectedMetric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.accent)
                    }
                    Text("\(selectedMetric.rawValue) \u{00B7} vs \(period.rawValue)")
                        .font(CadreTypography.trendsMetricName)
                        .tracking(-0.1)
                        .foregroundStyle(CadreColors.textPrimary)
                        .lineLimit(1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: CadreRadius.sm)
                            .fill(CadreColors.cardElevated)
                            .frame(width: 28, height: 28)
                        Image(systemName: selectedMetric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.accent)
                    }
                    Text(selectedMetric.rawValue)
                        .font(CadreTypography.trendsMetricName)
                        .tracking(-0.1)
                        .foregroundStyle(CadreColors.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: CadreRadius.md)
                    .fill(CadreColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CadreRadius.md)
                            .stroke(CadreColors.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Range tabs (M / 6M / Y / All)

    private var rangeTabs: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                let active = (vm?.timeRange ?? .month) == range
                Text(range.rawValue)
                    .font(CadreTypography.trendsRangeTab)
                    .foregroundStyle(active ? CadreColors.textPrimary : CadreColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(active ? CadreColors.cardElevated : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.25)) {
                            vm?.timeRange = range
                            vm?.refresh()
                        }
                        Haptics.selection()
                    }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(CadreColors.card)
        )
    }

    // MARK: - Full variant (2+ data points)

    private func fullBlock(points: [TrendDataPoint]) -> some View {
        let unit = selectedMetric.unit
        let latestValue = points.last?.value ?? 0
        let delta = (points.last?.value ?? 0) - (points.first?.value ?? 0)
        let periodSub = periodSubtitle(points: points, unit: unit)
        let ma = vm?.movingAverage ?? []

        let secondaryPoints = vm?.secondaryDataPoints ?? []

        return VStack(spacing: 0) {
            if compareEnabled, let secMetric = secondaryMetric, !secondaryPoints.isEmpty {
                dualHeroBlock(
                    primaryValue: latestValue, primaryUnit: unit, primaryLabel: selectedMetric.rawValue,
                    secondaryValue: secondaryPoints.last?.value ?? 0, secondaryUnit: secMetric.unit, secondaryLabel: secMetric.rawValue,
                    sub: periodSub
                )
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 16)
            } else if compareEnabled, let period = previousPeriod, !secondaryPoints.isEmpty {
                dualHeroBlock(
                    primaryValue: latestValue, primaryUnit: unit, primaryLabel: "Current",
                    secondaryValue: secondaryPoints.last?.value ?? 0, secondaryUnit: unit, secondaryLabel: period.rawValue,
                    sub: periodSub
                )
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 16)
            } else {
                heroBlock(latestValue: latestValue, unit: unit, delta: delta, sub: periodSub)
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 20)
            }

            chartBlock(points: points, movingAverage: ma)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 14)

            if !ma.isEmpty {
                legendBlock
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 10)
            }

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

    // MARK: - Hero (latest value)

    private func heroBlock(latestValue: Double, unit: String, delta: Double, sub: String) -> some View {
        let latestDate = vm?.dataPoints.last?.date

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatValue(latestValue))
                    .font(CadreTypography.trendsHero)
                    .tracking(-1.2)
                    .foregroundStyle(CadreColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: latestValue)
                if !unit.isEmpty {
                    Text(unit)
                        .font(CadreTypography.trendsHeroUnit)
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // Date label for hero — "Today" or relative date for weight; period subtitle otherwise
            if selectedMetric == .weight, let date = latestDate {
                Text(heroRelativeDate(from: date))
                    .font(CadreTypography.trendsHeroSub)
                    .foregroundStyle(CadreColors.textTertiary)
            } else {
                Text(sub)
                    .font(CadreTypography.trendsHeroSub)
                    .foregroundStyle(CadreColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dualHeroBlock(
        primaryValue: Double, primaryUnit: String, primaryLabel: String,
        secondaryValue: Double, secondaryUnit: String, secondaryLabel: String,
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
                        Text(formatValue(primaryValue))
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
                        Text(formatValue(secondaryValue))
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

    private func heroRelativeDate(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        if days < 7 { return "\(days) days ago" }
        return DateFormatting.shortDay(date)
    }

    // MARK: - Dual-axis normalization helpers

    /// Normalize a value into 0–1 range given a min/max. Returns 0.5 if range is zero.
    private func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max - min > 0 else { return 0.5 }
        return (value - min) / (max - min)
    }

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

    /// Compute 4 evenly-spaced real-value tick labels for a given min/max range.
    private func axisTickValues(min: Double, max: Double, count: Int = 4) -> [Double] {
        guard max - min > 0 else { return [min] }
        return (0..<count).map { i in
            min + (max - min) * Double(i) / Double(count - 1)
        }
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

        return Chart {
            ForEach(points) { point in
                let yVal = dualAxis ? normalize(point.value, min: primaryMin, max: primaryMax) : point.value
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", yVal),
                    series: .value("Series", "raw")
                )
                .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            }
            ForEach(points) { point in
                let yVal = dualAxis ? normalize(point.value, min: primaryMin, max: primaryMax) : point.value
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", yVal)
                )
                .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                .symbolSize(10)
            }
            ForEach(movingAverage) { point in
                let yVal = dualAxis ? normalize(point.value, min: primaryMin, max: primaryMax) : point.value
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
                    let yVal = dualAxis ? normalize(point.value, min: secMin, max: secMax) : point.value
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", yVal)
                    )
                    .foregroundStyle(secondaryColor)
                    .symbolSize(30)
                }
                ForEach(secondaryPoints) { point in
                    let yVal = dualAxis ? normalize(point.value, min: secMin, max: secMax) : point.value
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
                        Text(formatGoalLabel(goal.targetValue, unit: vm?.selectedMetric.unit ?? ""))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(CadreColors.accent)
                            .padding(.leading, 4)
                    }
            }
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
                AxisMarks(position: .trailing, values: axisTickValues(min: primaryMin, max: primaryMax).map { normalize($0, min: primaryMin, max: primaryMax) }) { mark in
                    AxisGridLine()
                        .foregroundStyle(CadreColors.chartGrid)
                    AxisValueLabel {
                        let norm = mark.as(Double.self) ?? 0
                        let real = primaryMin + norm * (primaryMax - primaryMin)
                        Text(formatValue(real))
                            .foregroundStyle(CadreColors.accent)
                            .font(CadreTypography.trendsAxisLabel)
                    }
                }
                // Left axis: secondary metric real values
                AxisMarks(position: .leading, values: axisTickValues(min: secMin, max: secMax).map { normalize($0, min: secMin, max: secMax) }) { mark in
                    AxisValueLabel {
                        let norm = mark.as(Double.self) ?? 0
                        let real = secMin + norm * (secMax - secMin)
                        Text(formatValue(real))
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
        .frame(height: 280)
        .overlay(alignment: .topTrailing) {
            expandStub
                .padding(8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(selectedMetric.rawValue) trend chart with \(points.count) data points")
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
                legendItem(color: CadreColors.accent, label: selectedMetric.rawValue)
                legendItem(color: secondaryColor, label: sec.rawValue, dashed: true)
            } else if compareEnabled, let period = previousPeriod {
                legendItem(color: CadreColors.accent, label: "Current")
                legendItem(color: secondaryColor, label: period.rawValue, dashed: true)
            } else {
                legendItem(color: CadreColors.textTertiary, label: "Daily")
                legendItem(color: CadreColors.chartLine, label: "7-day average")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            if dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color)
                            .frame(width: 3, height: 2)
                    }
                }
                .frame(width: 12)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 12, height: 2)
            }
            Text(label)
                .font(CadreTypography.trendsLegend)
                .foregroundStyle(CadreColors.textSecondary)
        }
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
                Text(value.map { formatValue($0) } ?? "\u{2014}")
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatValue(point.value))
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

    private var emptyStateBlock: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(CadreColors.cardElevated)
                    .frame(width: 42, height: 42)
                Image(systemName: selectedMetric.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
            }
            Text("No data yet")
                .font(CadreTypography.trendsEmptyTitle)
                .tracking(-0.1)
                .foregroundStyle(CadreColors.textPrimary)
            Text("Log an entry to start building your trend.")
                .font(CadreTypography.trendsEmptyBody)
                .foregroundStyle(CadreColors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Fullscreen chart (landscape two-column layout)

    private var fullscreenChartContent: some View {
        let points = vm?.dataPoints ?? []
        let ma = vm?.movingAverage ?? []
        let secondaryPoints = vm?.secondaryDataPoints ?? []
        let unit = selectedMetric.unit
        let latestValue = points.last?.value ?? 0
        let periodSub = periodSubtitle(points: points, unit: unit)
        let hasSecondary = compareEnabled && secondaryMetric != nil && !secondaryPoints.isEmpty

        return ZStack {
            CadreColors.bg.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left panel: metric info
                VStack(alignment: .leading, spacing: 12) {
                    if hasSecondary, let secMetric = secondaryMetric {
                        // Dual hero for compare mode
                        // Primary
                        HStack(spacing: 8) {
                            Circle().fill(CadreColors.accent).frame(width: 8, height: 8)
                            Text(selectedMetric.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CadreColors.textPrimary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(latestValue))
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
                            Text(formatValue(secondaryPoints.last?.value ?? 0))
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
                            Text(selectedMetric.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CadreColors.textPrimary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(latestValue))
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

                    Text(periodSub)
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

                    Chart {
                        ForEach(points) { point in
                            let yVal = fsDualAxis ? normalize(point.value, min: fsPrimaryMin, max: fsPrimaryMax) : point.value
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", yVal),
                                series: .value("Series", "raw")
                            )
                            .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                        }
                        ForEach(points) { point in
                            let yVal = fsDualAxis ? normalize(point.value, min: fsPrimaryMin, max: fsPrimaryMax) : point.value
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Value", yVal)
                            )
                            .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                            .symbolSize(10)
                        }
                        ForEach(ma) { point in
                            let yVal = fsDualAxis ? normalize(point.value, min: fsPrimaryMin, max: fsPrimaryMax) : point.value
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
                                let yVal = fsDualAxis ? normalize(point.value, min: fsSecMin, max: fsSecMax) : point.value
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", yVal)
                                )
                                .foregroundStyle(secondaryColor)
                                .symbolSize(30)
                            }
                            ForEach(secondaryPoints) { point in
                                let yVal = fsDualAxis ? normalize(point.value, min: fsSecMin, max: fsSecMax) : point.value
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", yVal),
                                    series: .value("Series", "secondary")
                                )
                                .foregroundStyle(secondaryColor)
                                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [4, 3]))
                            }
                        }
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
                            AxisMarks(position: .trailing, values: axisTickValues(min: fsPrimaryMin, max: fsPrimaryMax).map { normalize($0, min: fsPrimaryMin, max: fsPrimaryMax) }) { mark in
                                AxisGridLine()
                                    .foregroundStyle(CadreColors.chartGrid)
                                AxisValueLabel {
                                    let norm = mark.as(Double.self) ?? 0
                                    let real = fsPrimaryMin + norm * (fsPrimaryMax - fsPrimaryMin)
                                    Text(formatValue(real))
                                        .foregroundStyle(CadreColors.accent)
                                        .font(CadreTypography.trendsAxisLabel)
                                }
                            }
                            AxisMarks(position: .leading, values: axisTickValues(min: fsSecMin, max: fsSecMax).map { normalize($0, min: fsSecMin, max: fsSecMax) }) { mark in
                                AxisValueLabel {
                                    let norm = mark.as(Double.self) ?? 0
                                    let real = fsSecMin + norm * (fsSecMax - fsSecMin)
                                    Text(formatValue(real))
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
                    .padding()
                } else if let point = points.first {
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
                    .padding()
                } else {
                    Spacer()
                    Text("No data")
                        .font(CadreTypography.trendsEmptyTitle)
                        .foregroundStyle(CadreColors.textTertiary)
                    Spacer()
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showFullscreen = false
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

    // MARK: - Helpers

    /// Format a value for display (1 decimal place).
    private func formatValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatGoalLabel(_ value: Double, unit: String) -> String {
        let formatted = value == value.rounded() && value >= 10
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return formatted + " " + unit
    }

    /// Builds the "Mar 6 – Apr 4 · -0.8 lb / week" string under the hero.
    private func periodSubtitle(points: [TrendDataPoint], unit: String) -> String {
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

#Preview {
    TrendsView()
        .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
}
