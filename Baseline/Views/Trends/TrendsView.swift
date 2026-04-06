import SwiftUI
import SwiftData
import Charts
import TipKit

/// Trends tab — weight trend over selectable time range.
///
/// Visual target: `docs/mockups/trends-APPROVED-2026-04-05.html` (default
/// variant · "Weight + 7-day MA") and `docs/mockups/trends-edge-cases-2026-04-05.html`
/// (variants 01 zero-data, 02 single point, 03 sparse).
///
/// Layout: metric chip (visual stub) → range tabs (M/6M/Y/All) → hero delta →
/// chart (180pt, line + points + dashed 7-day MA) → legend → stats row.
///
/// **v1 scope — weight only.** Metric dropdown and expand icons are visual
/// stubs (no-ops). Compare mode, goals overlay, landscape, bucketing, and
/// previous-period overlay are deferred until the VM supports multiple
/// metrics. See task 13 scope notes and `docs/DESIGN_DECISIONS.md`
/// (Trends architecture, 2026-04-05).
struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: TrendsViewModel?

    /// Synchronous VM injection (snapshot / unit tests). Mirrors the
    /// `NowView(viewModel:)` pattern.
    private let injectedVM: TrendsViewModel?
    private let trendsTip = TrendsTip()

    init(viewModel: TrendsViewModel? = nil) {
        self.injectedVM = viewModel
        self._vm = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    metricChip
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
            .onAppear {
                guard injectedVM == nil else { return }
                if vm == nil {
                    vm = TrendsViewModel(modelContext: modelContext)
                }
                vm?.refresh()
            }
        }
    }

    // MARK: - Body state machine

    @ViewBuilder
    private var content: some View {
        let entries = vm?.entries ?? []

        if entries.isEmpty {
            emptyStateBlock
        } else if entries.count == 1 {
            singlePointBlock(entries: entries)
        } else {
            fullBlock(entries: entries)
        }
    }

    // MARK: - Metric chip (stub)
    // TODO: wire metric dropdown (Weight / Body Fat % / Skeletal Muscle / etc.)
    // once TrendsViewModel supports multi-metric. See DESIGN_DECISIONS.md
    // (2026-04-05 Trends architecture).
    private var metricChip: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: CadreRadius.sm)
                    .fill(CadreColors.cardElevated)
                    .frame(width: 28, height: 28)
                Image(systemName: "scalemass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.accent)
            }
            // Metric name — 14pt semibold, -0.1 tracking (mockup .metric-chip .metric-name)
            Text("Weight")
                .font(CadreTypography.trendsMetricName)
                .tracking(-0.1)
                .foregroundStyle(CadreColors.textPrimary)
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

    // MARK: - Range tabs (M / 6M / Y / All)

    private var rangeTabs: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                let active = (vm?.timeRange ?? .month) == range
                // Range tab label — 12pt medium (mockup .range-tabs .opt)
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

    // MARK: - Full variant (2+ entries)

    private func fullBlock(entries: [WeightEntry]) -> some View {
        let unit = entries.last?.unit ?? "lb"
        let delta = (entries.last?.weight ?? 0) - (entries.first?.weight ?? 0)
        let periodSub = periodSubtitle(entries: entries)
        let ma = vm?.movingAverage ?? []

        return VStack(spacing: 0) {
            heroBlock(delta: delta, unit: unit, sub: periodSub)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 20)

            chartBlock(entries: entries, movingAverage: ma)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 14)

            if !ma.isEmpty {
                legendBlock
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 10)
            }

            statsBlock(entries: entries, unit: unit)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 12)
        }
    }

    // MARK: - Hero (delta)

    private func heroBlock(delta: Double, unit: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Delta hero — 44pt bold, -1.2 tracking (mockup .single-hero .main-num)
                Text(UnitConversion.formatDelta(delta).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(CadreTypography.trendsHero)
                    .tracking(-1.2)
                    .foregroundStyle(CadreColors.accent)
                // Unit suffix — 15pt medium (mockup .single-hero .main-num .unit)
                Text(unit)
                    .font(CadreTypography.trendsHeroUnit)
                    .foregroundStyle(CadreColors.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // Period subtitle — 11pt medium (mockup .hero-sub)
            Text(sub)
                .font(CadreTypography.trendsHeroSub)
                .foregroundStyle(CadreColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart (Swift Charts)

    private func chartBlock(entries: [WeightEntry], movingAverage: [MovingAveragePoint]) -> some View {
        ZStack(alignment: .topTrailing) {
            Chart {
                // Raw daily line — dim, thin (mockup: #494B52, 1.3px, 0.7 opacity)
                ForEach(entries, id: \.id) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", entry.weight),
                        series: .value("Series", "raw")
                    )
                    .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                }
                // Points on raw series
                ForEach(entries, id: \.id) { entry in
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", entry.weight)
                    )
                    .foregroundStyle(CadreColors.textTertiary.opacity(0.7))
                    .symbolSize(10)
                }
                // 7-day moving average — thicker accent line (mockup: #6B7B94, 2.6px)
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
            .frame(height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weight trend chart with \(entries.count) data points")

            // Expand icon — visual stub, no-op.
            // TODO: wire to landscape fullscreen chart once landscape view is
            // built (trends-compare-v3-2026-04-05.html).
            expandStub
        }
    }

    private var expandStub: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(CadreColors.textSecondary)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(CadreColors.divider.opacity(0.7))
            )
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
            // Legend label — 9pt medium (mockup .legend-item)
            Text(label)
                .font(CadreTypography.trendsLegend)
                .foregroundStyle(CadreColors.textSecondary)
        }
    }

    // MARK: - Stats row (Start / Lowest / Current)

    private func statsBlock(entries: [WeightEntry], unit: String) -> some View {
        let start = entries.first?.weight
        let current = entries.last?.weight
        let lowest = entries.map(\.weight).min()

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
            // Uppercase caption — 9pt semibold, 0.5 tracking (mockup .stat .label)
            Text(label)
                .font(CadreTypography.trendsStatLabel)
                .tracking(0.5)
                .foregroundStyle(CadreColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // Stat value — 15pt bold (mockup .stat .value)
                Text(value.map { UnitConversion.formatWeight($0, unit: unit) } ?? "—")
                    .font(CadreTypography.trendsStatValue)
                    .foregroundStyle(CadreColors.textPrimary)
                if value != nil {
                    // Stat unit — 9pt regular (mockup .stat .value .unit)
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

    private func singlePointBlock(entries: [WeightEntry]) -> some View {
        let entry = entries[0]
        let unit = entry.unit
        return VStack(spacing: 0) {
            // Hero: raw value, no sign, no delta (mockup edge-case 02)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(UnitConversion.formatWeight(entry.weight, unit: unit))
                        .font(CadreTypography.trendsHero)
                        .tracking(-1.2)
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(unit)
                        .font(CadreTypography.trendsHeroUnit)
                        .foregroundStyle(CadreColors.textSecondary)
                }
                Text("Log more entries to see your trend")
                    .font(CadreTypography.trendsHeroSub)
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 20)

            singlePointChart(entry: entry)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 14)

            statsBlock(entries: entries, unit: unit)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 12)
        }
    }

    private func singlePointChart(entry: WeightEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            Chart {
                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(CadreColors.chartLine)
                .symbolSize(80)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: (entry.weight - 2)...(entry.weight + 2))
            .frame(height: 180)

            expandStub
        }
    }

    // MARK: - Empty state

    private var emptyStateBlock: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(CadreColors.cardElevated)
                    .frame(width: 42, height: 42)
                Image(systemName: "scalemass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
            }
            // Empty-state title — 13pt semibold, -0.1 tracking (mockup .ei-title)
            Text("No data yet")
                .font(CadreTypography.trendsEmptyTitle)
                .tracking(-0.1)
                .foregroundStyle(CadreColors.textPrimary)
            // Empty-state body — 11pt medium (mockup .ei-body)
            Text("Log an entry to start building your trend.")
                .font(CadreTypography.trendsEmptyBody)
                .foregroundStyle(CadreColors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Period subtitle helper

    /// Builds the "Mar 6 – Apr 4 · −0.8 lb / week" string under the hero.
    /// Falls back to "N entries in range" when the entry count is low enough
    /// that a per-week rate would mislead.
    private func periodSubtitle(entries: [WeightEntry]) -> String {
        guard let first = entries.first, let last = entries.last, entries.count >= 2 else {
            return ""
        }
        let spanDays = max(1, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
        let dateRange = "\(DateFormatting.shortDay(first.date)) – \(DateFormatting.shortDay(last.date))"

        // Sparse data: skip the per-week rate — it's noisy with few points.
        if entries.count < 7 {
            return "\(dateRange) · \(entries.count) entries"
        }

        let delta = last.weight - first.weight
        let weeks = Double(spanDays) / 7.0
        let perWeek = weeks > 0 ? delta / weeks : 0
        let perWeekStr = UnitConversion.formatDelta(perWeek)
            .replacingOccurrences(of: "-", with: "\u{2212}")
        let unit = last.unit
        return "\(dateRange) · \(perWeekStr) \(unit) / week"
    }
}

#Preview {
    TrendsView()
        .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
}
