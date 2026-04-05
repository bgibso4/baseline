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
                // WeighInSheet implemented in Task 10
                Text("Weigh In Sheet")
                    .font(CadreTypography.headline)
                    .foregroundStyle(CadreColors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CadreColors.bg)
                    .presentationDetents([.medium])
            }
            .navigationDestination(isPresented: $showSettings) {
                // Replaced in Task 18
                Text("Settings")
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .navigationDestination(isPresented: $showHistory) {
                // Replaced in Task 11
                Text("History")
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .onAppear {
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
                    Text("Today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            .frame(width: 290, height: 248)

            rangeToggle
        }
    }

    private var weightNumber: some View {
        let displayWeight = vm?.todayEntry?.weight ?? vm?.lastWeight
        let unit = vm?.todayEntry?.unit
            ?? UserDefaults.standard.string(forKey: "weightUnit")
            ?? "lb"
        let dimmed = vm?.todayEntry == nil && displayWeight != nil

        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let weight = displayWeight {
                Text(UnitConversion.formatWeight(weight, unit: unit))
                    .font(.system(size: 84, weight: .bold, design: .default))
                    .tracking(-2.5)
                    .foregroundStyle(dimmed ? CadreColors.textTertiary : CadreColors.textPrimary)
                Text(unit)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(CadreColors.textSecondary)
            } else {
                Text("—")
                    .font(.system(size: 84, weight: .bold))
                    .foregroundStyle(CadreColors.textTertiary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var rangeToggle: some View {
        HStack(spacing: 0) {
            ForEach(StatsRange.allCases, id: \.self) { option in
                Text(option.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selectedRange == option ? CadreColors.textPrimary : CadreColors.textSecondary)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(selectedRange == option ? CadreColors.cardElevated : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectedRange = option }
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
        let unit = vm?.todayEntry?.unit ?? "lb"
        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(CadreColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.map { UnitConversion.formatWeight($0, unit: unit) } ?? "—")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(CadreColors.textPrimary)
                if value != nil {
                    Text(unit)
                        .font(.system(size: 10, weight: .regular))
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
            Text("Weigh In")
                .font(.system(size: 16, weight: .semibold))
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

// MARK: - Arc indicator

/// 270° arc (from 225° bottom-left around the top to -45° bottom-right) with a
/// filled segment showing `fraction` (0...1) of the range, plus an endpoint dot.
/// Label content sits centered inside the arc.
private struct ArcIndicatorView<Content: View>: View {
    let fraction: Double?
    @ViewBuilder let content: () -> Content

    // Matches mockup: 290 × 248 SVG, radius 145, center at (145, 145)
    private let size = CGSize(width: 290, height: 248)
    private let radius: CGFloat = 145
    private let strokeWidth: CGFloat = 7
    // Arc spans 270°, from 135° (bottom-left) clockwise to 45° (bottom-right)
    // i.e. start at 135°, sweep 270° clockwise.
    private let startAngle = Angle.degrees(135)
    private let sweep: Double = 270

    var body: some View {
        ZStack {
            // Background arc
            ArcShape(startAngle: startAngle, sweepDegrees: sweep, radius: radius)
                .stroke(CadreColors.divider, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Progress arc
            if let fraction {
                ArcShape(startAngle: startAngle, sweepDegrees: sweep * fraction, radius: radius)
                    .stroke(CadreColors.accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

                // Endpoint dot
                endpointDot(at: fraction)
            }

            // Center content
            content()
                .position(x: size.width / 2, y: radius)
        }
        .frame(width: size.width, height: size.height)
    }

    private func endpointDot(at fraction: Double) -> some View {
        let angle = startAngle + .degrees(sweep * fraction)
        let center = CGPoint(x: size.width / 2, y: radius)
        let x = center.x + radius * CGFloat(cos(angle.radians))
        let y = center.y + radius * CGFloat(sin(angle.radians))
        return ZStack {
            Circle()
                .fill(CadreColors.accent)
                .frame(width: 18, height: 18)
            Circle()
                .fill(CadreColors.textPrimary)
                .frame(width: 7, height: 7)
        }
        .position(x: x, y: y)
    }
}

/// Arc drawn from `startAngle`, sweeping clockwise by `sweepDegrees` around the
/// view's top-center (x = width/2, y = radius). Matches the SVG arc convention
/// used in the approved mockup.
private struct ArcShape: Shape {
    let startAngle: Angle
    let sweepDegrees: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: radius)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: startAngle + .degrees(sweepDegrees),
            clockwise: false
        )
        return path
    }
}

#Preview {
    NowView()
        .modelContainer(for: [WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self], inMemory: true)
}
