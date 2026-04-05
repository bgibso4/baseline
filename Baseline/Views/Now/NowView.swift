import SwiftUI
import SwiftData

/// Today (now) screen — landing glance at current weight.
///
/// Visual target: `docs/mockups/today-APPROVED-variant-a-2026-04-04.html`.
/// Layout: toolbar (gear / list) → hero arc + number + range toggle (centered
/// in open area) → stats card → Weigh In button anchored above tab bar.
struct NowView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: NowViewModel?
    @State private var showWeighIn = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var selectedRange: StatsRange = .thirtyDays

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
                CadreColors.bg.ignoresSafeArea()

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
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHistory = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showWeighIn) {
                WeighInSheet(
                    lastWeight: vm?.todayEntry?.weight ?? vm?.lastWeight,
                    unit: vm?.unit ?? "lb",
                    onSave: { vm?.refresh() }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
            .navigationDestination(isPresented: $showSettings) {
                // Replaced in Task 18
                Text("Settings")
                    .foregroundStyle(CadreColors.textPrimary)
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
            }
        }
    }

    // MARK: - Hero group (arc + number + range toggle)

    private var heroGroup: some View {
        VStack(spacing: CadreSpacing.lg) {
            ArcIndicatorView(fraction: arcFraction) {
                VStack(spacing: 10) {
                    weightNumber
                    // "Today" caption inside the arc
                    Text("Today")
                        .font(CadreTypography.todayLabel)
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            .frame(width: 290, height: 248)

            rangeToggle
        }
    }

    private var weightNumber: some View {
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
                        // TODO: wire to VM window (follow-up) — currently inert.
                        selectedRange = option
                    }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(CadreColors.card)
        )
    }

    // MARK: - Bottom block (stats + button)

    private var bottomBlock: some View {
        VStack(spacing: 18) {
            statsCard
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
        .background(CadreColors.divider)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        .background(CadreColors.card)
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

    /// Where today's weight sits within the recent min–max range, 0...1.
    /// Returns nil if we lack data for a meaningful arc.
    private var arcFraction: Double? {
        guard let current = vm?.todayEntry?.weight ?? vm?.lastWeight,
              let weights = vm?.recentWeights,
              weights.count >= 2
        else { return nil }

        let values = weights.map(\.weight)
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return nil }
        return max(0, min(1, (current - lo) / (hi - lo)))
    }

    private var computedStats: (lowest: Double?, average: Double?, highest: Double?) {
        let values = (vm?.recentWeights ?? []).map(\.weight)
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
