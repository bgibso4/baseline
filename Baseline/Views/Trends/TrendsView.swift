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
                                // previous range. (The chart clears its own
                                // crosshair selection on timeRange change.)
                                vm?.windowEndDate = Date()
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
        // A real cold-start (no data at all) shows the log-your-first-entry
        // CTA — there's no chart or hero to render. Anything else (a populated
        // window, or a stepped-back empty window with prior data) goes to the
        // chart section, which picks the full / single-point / window-empty
        // variant internally.
        if (vm?.dataPoints ?? []).isEmpty && vm?.latestPoint == nil {
            TrendsEmptyState(
                metric: selectedMetric,
                onSelectTab: { appState?.selectedTab = $0 }
            )
        } else {
            TrendsChartSection(
                vm: vm,
                goalVM: goalVM,
                compareEnabled: compareEnabled,
                secondaryMetric: secondaryMetric,
                previousPeriod: previousPeriod,
                secondaryColor: secondaryColor,
                onExpand: { showFullscreen = true },
                onSetGoal: { showSetGoal = true },
                onManageGoal: { showManageGoal = true }
            )
        }
    }

    // MARK: - Shared palette

    /// Dusty secondary accent used for the compare / secondary-metric series.
    /// Threaded into `TrendsMetricChip` and the chart/legend/hero rendering.
    private let secondaryColor = Color(hex: "B89968")
}

#Preview {
    TrendsView()
        .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
}
