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
    @State private var vm: TrendsViewModel?
    @State private var showMetricSheet = false
    @State private var compareEnabled = false
    @State private var secondaryMetric: TrendMetric?
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
                    availableMetrics: availableMetrics,
                    onDismiss: { vm?.refresh() }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(red: 28/255, green: 28/255, blue: 34/255))
            }
            .onAppear {
                guard injectedVM == nil else { return }
                if vm == nil {
                    vm = TrendsViewModel(modelContext: modelContext)
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

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    private var metricChipButton: some View {
        Button {
            showMetricSheet = true
        } label: {
            HStack(spacing: 10) {
                if compareEnabled, let secondary = secondaryMetric {
                    // Dual-icon stack for compare mode
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
                            .foregroundStyle(amber)
                            .offset(x: 5, y: 4)
                    }
                    Text("\(selectedMetric.rawValue) \u{00B7} \(secondary.rawValue)")
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
                        vm?.timeRange = range
                        vm?.refresh()
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

        return VStack(spacing: 0) {
            heroBlock(latestValue: latestValue, unit: unit, delta: delta, sub: periodSub)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 20)

            chartBlock(points: points, movingAverage: ma)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 14)

            if !ma.isEmpty {
                legendBlock
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 10)
            }

            statsBlock(points: points, unit: unit)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 12)
        }
    }

    // MARK: - Hero (latest value)

    private func heroBlock(latestValue: Double, unit: String, delta: Double, sub: String) -> some View {
        let latestDate = vm?.dataPoints.last?.date
        let isLatestToday = latestDate.map { Calendar.current.isDateInToday($0) } ?? false
        // Weight dims when no entry today; scan metrics always show full color
        let dimmed = (selectedMetric == .weight) && !isLatestToday

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatValue(latestValue))
                    .font(CadreTypography.trendsHero)
                    .tracking(-1.2)
                    .foregroundStyle(dimmed ? CadreColors.textTertiary : CadreColors.accent)
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

    private func heroRelativeDate(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        if days < 7 { return "\(days) days ago" }
        return DateFormatting.shortDay(date)
    }

    // MARK: - Chart (Swift Charts)

    private func chartBlock(points: [TrendDataPoint], movingAverage: [MovingAveragePoint]) -> some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value),
                    series: .value("Series", "raw")
                )
                .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            }
            ForEach(points) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                .symbolSize(10)
            }
            ForEach(movingAverage) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("MA", point.value),
                    series: .value("Series", "ma")
                )
                .foregroundStyle(CadreColors.chartLine)
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
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
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(CadreColors.chartGrid)
                AxisValueLabel()
                    .foregroundStyle(CadreColors.textTertiary)
                    .font(CadreTypography.trendsAxisLabel)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
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
            legendItem(color: CadreColors.textTertiary, label: "Daily")
            legendItem(color: CadreColors.chartLine, label: "7-day average")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 12, height: 2)
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

            statsBlock(points: points, unit: unit)
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
        let unit = selectedMetric.unit
        let latestValue = points.last?.value ?? 0
        let periodSub = periodSubtitle(points: points, unit: unit)

        return ZStack {
            CadreColors.bg.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left panel: metric info
                VStack(alignment: .leading, spacing: 12) {
                    // Metric name with icon dot
                    HStack(spacing: 8) {
                        Circle()
                            .fill(CadreColors.accent)
                            .frame(width: 8, height: 8)
                        Text(selectedMetric.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.textPrimary)
                    }

                    // Hero value (latest)
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

                    // Date range + rate
                    Text(periodSub)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)

                    Spacer()
                }
                .frame(width: 180)
                .padding()

                // Right: chart fills remaining space
                if points.count >= 2 {
                    Chart {
                        ForEach(points) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value),
                                series: .value("Series", "raw")
                            )
                            .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                        }
                        ForEach(points) { point in
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                            .symbolSize(10)
                        }
                        ForEach(ma) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("MA", point.value),
                                series: .value("Series", "ma")
                            )
                            .foregroundStyle(CadreColors.chartLine)
                            .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
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
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 6)) { _ in
                            AxisGridLine()
                                .foregroundStyle(CadreColors.chartGrid)
                            AxisValueLabel()
                                .foregroundStyle(CadreColors.textTertiary)
                                .font(CadreTypography.trendsAxisLabel)
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
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
