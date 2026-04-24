import SwiftUI
import SwiftData
import TipKit

/// Body tab — 2-column tile grid of body composition and measurement metrics.
///
/// Visual target: `docs/mockups/body-v1-2026-04-05.html` (Variant B — approved),
/// `docs/mockups/body-v4-refinements-2026-04-05.html` (Scan History card).
///
/// Two sections: Body Composition (InBody scan-derived) and Measurements (tape).
/// Scan History card below body comp tiles. Tapping a tile navigates to Trends
/// with that metric pre-selected (stubbed for now).
struct BodyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState: AppState?

    // Track unit preferences so SwiftUI re-renders when they change
    @AppStorage("weightUnit") private var weightUnit = "lb"
    @AppStorage("lengthUnit") private var lengthUnit = "in"

    private let injectedVM: BodyViewModel?
    @State private var vm: BodyViewModel?
    @State private var showLogMeasurement = false
    @State private var showScanEntry = false
    private let scanTip = ScanTip()

    init(viewModel: BodyViewModel? = nil) {
        self.injectedVM = viewModel
        self._vm = State(initialValue: viewModel)
    }

    /// Seed `@State` with a preloaded VM without marking it as
    /// test-injected. See `TrendsView.init(preloadedVM:)` for rationale.
    init(preloadedVM: BodyViewModel?) {
        self.injectedVM = nil
        self._vm = State(initialValue: preloadedVM)
    }

    // MARK: - Grid

    private let tileColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(center: .top)

                ScrollView {
                    VStack(spacing: 0) {
                        TipView(scanTip)
                            .padding(.horizontal, CadreSpacing.sheetHorizontal)
                            .padding(.top, 8)
                        bodyCompositionSection
                        scanHistoryCard
                            .padding(.horizontal, CadreSpacing.sheetHorizontal)
                            .padding(.top, 16)
                        measurementsSection
                            .padding(.top, 8)
                    }
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // No title — tab label handles it per design decisions
                    EmptyView()
                }
            }
        }
        .onAppear {
            guard injectedVM == nil else { return }
            if vm == nil {
                vm = (appState?.preloadedBodyVM as? BodyViewModel)
                    ?? BodyViewModel(modelContext: modelContext)
            }
            vm?.refresh()
        }
        .sheet(isPresented: $showLogMeasurement) {
            LogMeasurementSheet(viewModel: vm)
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showScanEntry) {
            vm?.refresh()
        } content: {
            ScanEntryFlow()
        }
    }

    // MARK: - Body Composition

    private var bodyCompositionSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Body Composition",
                meta: scanMetaText,
                action: {
                    showScanEntry = true
                }
            )

            if let tiles = bodyCompTiles, !tiles.isEmpty {
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(tiles, id: \.label) { tile in
                        if let trendName = trendMetricName(for: tile.label) {
                            Button {
                                appState?.trendMetric = trendName
                                appState?.selectedTab = .trends
                            } label: {
                                MetricTile(
                                    sfSymbol: tile.sfSymbol,
                                    label: tile.label,
                                    value: tile.value,
                                    unit: tile.unit,
                                    delta: tile.delta,
                                    isSecondaryAccent: tile.isSecondary
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                MetricHistoryView(
                                    metricName: tile.label,
                                    unit: tile.unit,
                                    entries: bodyCompHistory(for: tile.label)
                                )
                            } label: {
                                MetricTile(
                                    sfSymbol: tile.sfSymbol,
                                    label: tile.label,
                                    value: tile.value,
                                    unit: tile.unit,
                                    delta: tile.delta,
                                    isSecondaryAccent: tile.isSecondary
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .transition(.opacity)
            }
        }
        .animation(.easeIn(duration: 0.25), value: bodyCompTiles?.count)
    }

    // MARK: - Measurements

    private var measurementsSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Measurements",
                meta: measurementMetaText,
                action: {
                    showLogMeasurement = true
                }
            )

            let tiles = measurementTiles
            if !tiles.isEmpty {
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(tiles, id: \.label) { tile in
                        MeasurementTileLink(
                            tile: tile,
                            trendName: trendMetricNameForMeasurement(tile.label),
                            appState: appState
                        )
                    }
                }
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
            }
        }
    }

    // MARK: - Scan History Card

    private var scanHistoryCard: some View {
        NavigationLink {
            ScanHistoryView(
                scans: vm?.recentScans ?? [],
                onDelete: { scan in vm?.deleteScan(scan) },
                decodedPayload: { scan in vm?.decodedPayload(for: scan) }
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CadreColors.accent)
                    .frame(width: 32, height: 32)
                    .background(CadreColors.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan History")
                        .font(CadreTypography.scanHistoryTitle)
                        .tracking(-0.2)
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(scanHistorySubtitle)
                        .font(CadreTypography.scanHistoryMeta)
                        .foregroundStyle(CadreColors.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // Scan history placeholder removed — replaced by ScanHistoryView

    // MARK: - Section Header

    private func sectionHeader(title: String, meta: String, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(CadreTypography.bodySectionTitle)
                    .tracking(0.6)
                    .foregroundStyle(CadreColors.textSecondary)
                if !meta.isEmpty {
                    Text(meta)
                        .font(CadreTypography.bodySectionMeta)
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.accent)
                    .frame(width: 28, height: 28)
                    .background(CadreColors.cardElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    // MARK: - Data Mapping

    private struct TileData {
        let sfSymbol: String
        let label: String
        let value: String
        let unit: String
        let delta: MetricTile.Delta?
        var isSecondary: Bool = false
    }

    /// Build tile data from the most recent scan payload.
    private var bodyCompTiles: [TileData]? {
        // Reference @AppStorage so SwiftUI re-evaluates when unit changes
        _ = weightUnit
        guard let scan = vm?.recentScans.first,
              let content = vm?.decodedPayload(for: scan) else { return nil }

        switch content {
        case .inBody(let p):
            let smm = UnitConversion.formattedMass(p.skeletalMuscleMassKg)
            let fm = UnitConversion.formattedMass(p.bodyFatMassKg)
            var tiles: [TileData] = []
            tiles.append(TileData(
                sfSymbol: "drop.fill",
                label: "Body Fat",
                value: String(format: "%.1f", p.bodyFatPct),
                unit: "%",
                delta: nil,
                isSecondary: true
            ))
            tiles.append(TileData(
                sfSymbol: "figure.strengthtraining.traditional",
                label: "Skeletal Muscle",
                value: smm.text,
                unit: smm.unit,
                delta: nil
            ))
            tiles.append(TileData(
                sfSymbol: "scalemass",
                label: "Fat Mass",
                value: fm.text,
                unit: fm.unit,
                delta: nil,
                isSecondary: true
            ))
            tiles.append(TileData(
                sfSymbol: "chart.bar",
                label: "BMI",
                value: String(format: "%.1f", p.bmi),
                unit: "",
                delta: nil
            ))
            tiles.append(TileData(
                sfSymbol: "drop",
                label: "Total Body Water",
                value: String(format: "%.1f", p.totalBodyWaterL),
                unit: "L",
                delta: nil
            ))
            tiles.append(TileData(
                sfSymbol: "flame",
                label: "BMR",
                value: String(format: "%.0f", p.basalMetabolicRate),
                unit: "kcal",
                delta: nil
            ))
            if let score = p.inBodyScore {
                tiles.append(TileData(
                    sfSymbol: "star",
                    label: "InBody Score",
                    value: String(format: "%.0f", score),
                    unit: "",
                    delta: nil
                ))
            }
            if let lbm = p.leanBodyMassKg {
                let lbmDisplay = UnitConversion.formattedMass(lbm)
                tiles.append(TileData(
                    sfSymbol: "figure.stand",
                    label: "Lean Body Mass",
                    value: lbmDisplay.text,
                    unit: lbmDisplay.unit,
                    delta: nil
                ))
            }
            return tiles
        }
    }

    /// Build tile data from latest tape measurements (only metrics with data).
    /// Ordered by `MeasurementType.allCases` for consistent display.
    private var measurementTiles: [TileData] {
        // Reference @AppStorage so SwiftUI re-evaluates when unit changes
        _ = lengthUnit
        guard let measurements = vm?.latestMeasurements else { return [] }
        let byType = Dictionary(grouping: measurements) { $0.type }
        return MeasurementType.allCases.compactMap { type -> TileData? in
            guard let m = byType[type.rawValue]?.first else { return nil }
            let display = UnitConversion.formattedLength(m.valueCm)
            return TileData(
                sfSymbol: type.sfSymbol,
                label: type.tileLabel,
                value: display.text,
                unit: display.unit,
                delta: nil
            )
        }
    }

    // MARK: - Meta Text

    private var scanMetaText: String {
        guard let scan = vm?.recentScans.first else { return "No scans" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Last scan \u{00B7} \(formatter.string(from: scan.date))"
    }

    private var measurementMetaText: String {
        guard let m = vm?.latestMeasurements.first else { return "No measurements" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Last logged \u{00B7} \(formatter.string(from: m.date))"
    }

    // MARK: - Metric History Helpers

    /// Extract history for a body comp metric across all scans (reverse chronological).
    private func bodyCompHistory(for label: String) -> [(date: Date, value: String)] {
        guard let scans = vm?.recentScans else { return [] }
        return scans.compactMap { scan -> (date: Date, value: String)? in
            guard let content = vm?.decodedPayload(for: scan) else { return nil }
            switch content {
            case .inBody(let p):
                let val: String? = {
                    switch label {
                    case "Body Fat": return String(format: "%.1f", p.bodyFatPct)
                    case "Skeletal Muscle": return UnitConversion.formattedMass(p.skeletalMuscleMassKg).text
                    case "Fat Mass": return UnitConversion.formattedMass(p.bodyFatMassKg).text
                    case "BMI": return String(format: "%.1f", p.bmi)
                    case "Total Body Water": return String(format: "%.1f", p.totalBodyWaterL)
                    case "BMR": return String(format: "%.0f", p.basalMetabolicRate)
                    case "InBody Score": return p.inBodyScore.map { String(format: "%.0f", $0) }
                    case "Lean Body Mass": return p.leanBodyMassKg.map { UnitConversion.formattedMass($0).text }
                    default: return nil
                    }
                }()
                guard let v = val else { return nil }
                return (date: scan.date, value: v)
            }
        }
    }

    /// Maps a body comp tile label to the corresponding Trends metric name.
    /// All scan-derived metrics route to Trends with the matching TrendMetric.
    private func trendMetricName(for tileLabel: String) -> String? {
        switch tileLabel {
        case "Body Fat": return TrendMetric.bodyFatPct.rawValue
        case "Skeletal Muscle": return TrendMetric.skeletalMuscle.rawValue
        case "BMI": return TrendMetric.bmi.rawValue
        case "Fat Mass": return TrendMetric.fatMass.rawValue
        case "Total Body Water": return TrendMetric.totalBodyWater.rawValue
        case "BMR": return TrendMetric.bmr.rawValue
        case "InBody Score": return TrendMetric.inBodyScore.rawValue
        case "Lean Body Mass": return TrendMetric.leanBodyMass.rawValue
        default: return nil
        }
    }

    /// Maps a measurement tile label to Trends metric name.
    /// All measurements navigate to their own history view, not Trends.
    private func trendMetricNameForMeasurement(_ tileLabel: String) -> String? {
        return nil
    }

    // MARK: - Measurement Tile Link

    /// Extracted to a separate struct to reduce Swift type-checker complexity.
    private struct MeasurementTileLink: View {
        let tile: TileData
        let trendName: String?
        let appState: AppState?

        var body: some View {
            if let trendName {
                Button {
                    appState?.trendMetric = trendName
                    appState?.selectedTab = .trends
                } label: {
                    MetricTile(
                        sfSymbol: tile.sfSymbol,
                        label: tile.label,
                        value: tile.value,
                        unit: tile.unit,
                        delta: tile.delta
                    )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    MeasurementHistoryView(
                        metricType: MeasurementType.allCases.first(where: { $0.tileLabel == tile.label }) ?? .waist
                    )
                } label: {
                    MetricTile(
                        sfSymbol: tile.sfSymbol,
                        label: tile.label,
                        value: tile.value,
                        unit: tile.unit,
                        delta: tile.delta
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scanHistorySubtitle: String {
        guard let scans = vm?.recentScans, !scans.isEmpty else { return "No scans yet" }
        let count = scans.count
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let oldest = scans.last?.date ?? Date()
        return "\(count) scan\(count == 1 ? "" : "s") \u{00B7} since \(formatter.string(from: oldest))"
    }
}

#Preview {
    BodyView()
        .modelContainer(for: [Scan.self, Measurement.self], inMemory: true)
        .preferredColorScheme(.dark)
}
