import SwiftUI
import SwiftData
import TipKit

/// Today (now) screen — landing glance at current weight.
///
/// Visual target: `docs/mockups/today-APPROVED-variant-a-2026-04-04.html`.
/// Layout: toolbar (gear / list) → hero arc + number + range toggle (centered
/// in open area) → stats card → Weigh In button anchored above tab bar.
struct NowView: View {
    @Environment(\.modelContext) private var modelContext

    // Track unit preference so SwiftUI re-renders when it changes
    @AppStorage("weightUnit") private var weightUnit = "lb"

    @State private var vm: NowViewModel?
    @State private var goalVM: GoalViewModel?
    @State private var showGoalStats = true
    @State private var showWeighIn = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var selectedRange: StatsRange = .thirtyDays
    @State private var showGoalReached = false
    @State private var reachedGoalTarget: Double = 0
    @State private var reachedGoalStart: Double = 0
    @State private var reachedGoalStartDate: Date = Date()

    /// When non-nil, the view uses this VM directly and skips the `.onAppear`
    /// lazy init. Lets snapshot/unit tests pre-load state synchronously.
    private let injectedVM: NowViewModel?

    init(viewModel: NowViewModel? = nil) {
        self.injectedVM = viewModel
        self._vm = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(center: .top)

                VStack(spacing: 0) {
                    // Hero: arc + number + range toggle, centered in open area
                    Spacer(minLength: 0)

                    heroGroup
                        .padding(.horizontal, CadreSpacing.md)

                    Spacer(minLength: 0)

                    // Bottom: stats card + weigh in button
                    bottomBlock
                        .padding(.horizontal, 22)
                        .padding(.bottom, CadreSpacing.sm)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHistory = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWeighIn) {
                WeighInSheet(
                    lastWeight: vm?.todayEntry?.weight ?? vm?.lastWeight,
                    unit: vm?.unit ?? "lb",
                    onSave: {
                        vm?.refresh()
                        // Check goal completion after refresh
                        if let goalVM, let goal = goalVM.activeWeightGoal {
                            let currentWeight = vm?.todayEntry?.weight ?? 0
                            let displayWeight = UnitConversion.displayWeight(currentWeight, storedUnit: vm?.todayEntry?.unit ?? "lb")
                            // Capture goal info before completion marks it done
                            let target = goal.targetValue
                            let start = goal.startValue
                            let startDate = goal.startDate
                            if goalVM.checkCompletion(metricKey: TrendMetric.weight.rawValue, currentValue: displayWeight) {
                                reachedGoalTarget = target
                                reachedGoalStart = start
                                reachedGoalStartDate = startDate
                                showGoalReached = true
                            }
                        }
                    }
                )
                .presentationDragIndicator(.hidden)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
            }
            .onAppear {
                // If a VM was injected, skip lazy init entirely — the caller
                // has already refreshed. This keeps snapshot tests deterministic.
                guard injectedVM == nil else { return }
                if vm == nil {
                    vm = NowViewModel(modelContext: modelContext)
                }
                vm?.refresh()
                if goalVM == nil {
                    goalVM = GoalViewModel(modelContext: modelContext)
                }
                goalVM?.refresh()
            }
            .overlay {
                if showGoalReached {
                    GoalReachedOverlay(
                        targetValue: reachedGoalTarget,
                        startValue: reachedGoalStart,
                        unit: vm?.unit ?? "lb",
                        startDate: reachedGoalStartDate,
                        onNewGoal: {
                            showGoalReached = false
                            // Goal is already completed, user can go to Trends to set a new one
                        },
                        onDismiss: {
                            showGoalReached = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Hero group (arc + number + range toggle)

    private var heroGroup: some View {
        VStack(spacing: CadreSpacing.lg) {
            ArcIndicatorView(fraction: arcFraction) {
                VStack(spacing: 10) {
                    weightNumber
                    // Date caption inside the arc — "Today" or relative date
                    Text(heroDateLabel)
                        .font(CadreTypography.todayLabel)
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            .frame(width: 290, height: 248)
            .animation(.easeInOut(duration: 0.4), value: arcFraction)

            rangeToggle
        }
    }

    private var heroDateLabel: String {
        if vm?.todayEntry != nil {
            return "Today"
        }
        guard let previous = vm?.previousEntry else {
            return "Today"
        }
        return relativeDate(from: previous.date)
    }

    private func relativeDate(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        if days < 7 { return "\(days) days ago" }
        return DateFormatting.shortDay(date)
    }

    private var weightNumber: some View {
        _ = weightUnit  // SwiftUI dependency: re-render when unit preference changes
        let displayWeight = vm?.todayEntry?.weight ?? vm?.lastWeight
        let unit = vm?.unit ?? "lb"
        let dimmed = vm?.todayEntry == nil && displayWeight != nil

        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let weight = displayWeight {
                // Hero weight number — 84pt bold, -2.5 tracking (mockup .weight-num)
                Text(UnitConversion.formatWeight(weight, unit: unit))
                    .font(CadreTypography.weightHero)
                    .tracking(-2.5)
                    .foregroundStyle(dimmed ? CadreColors.textTertiary : CadreColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: weight)
                // Unit suffix — 24pt medium (mockup .weight-num .unit)
                Text(unit)
                    .font(CadreTypography.weightUnit)
                    .foregroundStyle(CadreColors.textSecondary)
            } else {
                Text("—")
                    .font(CadreTypography.weightHero)
                    .foregroundStyle(CadreColors.textTertiary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weightAccessibilityLabel)
    }

    private var weightAccessibilityLabel: String {
        let displayWeight = vm?.todayEntry?.weight ?? vm?.lastWeight
        let unit = vm?.unit ?? "lb"
        guard let weight = displayWeight else { return "No weight recorded" }
        let dimmedNote = (vm?.todayEntry == nil) ? ", from a previous day" : ""
        return "\(UnitConversion.formatWeight(weight, unit: unit)) \(unit)\(dimmedNote)"
    }

    private var rangeToggle: some View {
        HStack(spacing: 0) {
            ForEach(StatsRange.allCases, id: \.self) { option in
                // 30D / 90D / All segment — 12pt medium (mockup .toggle .opt)
                Text(option.label)
                    .font(CadreTypography.toggleOption)
                    .foregroundStyle(selectedRange == option ? CadreColors.textPrimary : CadreColors.textSecondary)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(selectedRange == option ? CadreColors.cardElevated : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedRange = option
                        }
                        Haptics.selection()
                    }
            }
        }
        .padding(3)
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Bottom block (stats + button)

    private var bottomBlock: some View {
        VStack(spacing: 18) {
            if goalVM?.activeWeightGoal != nil, showGoalStats {
                goalStatsCard
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.25)) {
                            showGoalStats.toggle()
                        }
                        Haptics.selection()
                    }
            } else {
                statsCard
                    .onTapGesture {
                        if goalVM?.activeWeightGoal != nil {
                            withAnimation(.snappy(duration: 0.25)) {
                                showGoalStats.toggle()
                            }
                            Haptics.selection()
                        }
                    }
            }
            weighInButton
        }
    }

    private var statsCard: some View {
        let stats = computedStats
        return HStack(spacing: 1) {
            statCell(label: "LOWEST", value: stats.lowest)
            statCell(label: "AVERAGE", value: stats.average)
            statCell(label: "HIGHEST", value: stats.highest)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .glassCard(cornerRadius: 14)
    }

    private var goalStatsCard: some View {
        let unit = vm?.unit ?? "lb"
        let currentEntry = vm?.todayEntry ?? vm?.recentWeights.first
        let currentDisplay: Double? = currentEntry.map { displayWeight(for: $0) }
        let goal = goalVM?.activeWeightGoal
        let targetDisplay: Double? = goal.map { UnitConversion.displayWeight($0.targetValue, storedUnit: "lb") }
        let remaining: Double? = {
            guard let goal, currentDisplay != nil else { return nil }
            // Use stored unit value for goal computation (goal.targetValue is in stored units)
            let currentStored = currentEntry.map { $0.weight } ?? 0.0
            return goal.remaining(currentValue: currentStored)
        }()
        let remainingDisplay: Double? = remaining.map { UnitConversion.displayWeight($0, storedUnit: "lb") }
        let daysLeft: Int? = goal?.daysRemaining

        return HStack(spacing: 1) {
            goalStatCell(label: "CURRENT", value: currentDisplay, unit: unit, accent: false, daysLeft: nil)
            goalStatCell(label: "TARGET", value: targetDisplay, unit: unit, accent: true, daysLeft: nil)
            goalStatCell(label: daysLeft.map { "TO GO (\($0)d)" } ?? "TO GO", value: remainingDisplay, unit: unit, accent: false, daysLeft: nil)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .glassCard(cornerRadius: 14)
    }

    private func goalStatCell(label: String, value: Double?, unit: String, accent: Bool, daysLeft: Int?) -> some View {
        let labelColor: Color = accent ? CadreColors.accent : CadreColors.textTertiary
        let valueColor: Color = accent ? CadreColors.accent : CadreColors.textPrimary
        return VStack(spacing: 6) {
            Text(label)
                .font(CadreTypography.statLabel)
                .tracking(0.5)
                .foregroundStyle(labelColor)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.map { UnitConversion.formatWeight($0, unit: unit) } ?? "—")
                    .font(CadreTypography.statValue)
                    .foregroundStyle(valueColor)
                    .contentTransition(.numericText())
                if value != nil {
                    Text(unit)
                        .font(CadreTypography.statUnit)
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(CadreColors.card)
    }

    private func statCell(label: String, value: Double?) -> some View {
        let unit = vm?.unit ?? "lb"
        return VStack(spacing: 6) {
            // Uppercase caption — 9pt semibold, 0.5px tracking (mockup .stat .label)
            Text(label)
                .font(CadreTypography.statLabel)
                .tracking(0.5)
                .foregroundStyle(CadreColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // Stat value — 18pt bold (mockup .stat .value)
                Text(value.map { UnitConversion.formatWeight($0, unit: unit) } ?? "—")
                    .font(CadreTypography.statValue)
                    .foregroundStyle(CadreColors.textPrimary)
                    .contentTransition(.numericText())
                if value != nil {
                    // Stat unit suffix — 10pt regular (mockup .stat .value .unit)
                    Text(unit)
                        .font(CadreTypography.statUnit)
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(CadreColors.cardGlass)
    }

    private var weighInButton: some View {
        Button {
            showWeighIn = true
        } label: {
            // Primary button label — 16pt semibold, 0.3px tracking (mockup .weigh-btn)
            Text("Weigh In")
                .font(CadreTypography.buttonLabel)
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(CadreColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Derived data

    /// Filters all weight entries by the selected range toggle.
    private var filteredWeights: [WeightEntry] {
        guard let weights = vm?.recentWeights else { return [] }
        let calendar = Calendar.current
        let now = Date()
        switch selectedRange {
        case .thirtyDays:
            let cutoff = calendar.date(byAdding: .day, value: -30, to: now)!
            return weights.filter { $0.date >= cutoff }
        case .ninetyDays:
            let cutoff = calendar.date(byAdding: .day, value: -90, to: now)!
            return weights.filter { $0.date >= cutoff }
        case .all:
            return weights
        }
    }

    /// Convert a weight entry's stored value to the user's preferred display unit.
    private func displayWeight(for entry: WeightEntry) -> Double {
        UnitConversion.displayWeight(entry.weight, storedUnit: entry.unit)
    }

    /// Where today's weight sits within the recent min–max range, 0...1.
    /// Returns nil if we lack data for a meaningful arc.
    private var arcFraction: Double? {
        _ = weightUnit  // SwiftUI dependency: re-render when unit preference changes
        guard let current = vm?.lastWeight,
              filteredWeights.count >= 2
        else { return nil }

        let values = filteredWeights.map { displayWeight(for: $0) }
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return nil }
        return max(0, min(1, (current - lo) / (hi - lo)))
    }

    private var computedStats: (lowest: Double?, average: Double?, highest: Double?) {
        _ = weightUnit  // SwiftUI dependency: re-render when unit preference changes
        let values = filteredWeights.map { displayWeight(for: $0) }
        guard !values.isEmpty else { return (nil, nil, nil) }
        let avg = values.reduce(0, +) / Double(values.count)
        return (values.min(), avg, values.max())
    }
}

// MARK: - Range toggle

private enum StatsRange: CaseIterable {
    case thirtyDays
    case ninetyDays
    case all

    var label: String {
        switch self {
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        case .all: return "All"
        }
    }
}

#Preview {
    NowView()
        .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
}
