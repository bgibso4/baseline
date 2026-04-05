import SwiftUI
import SwiftData

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

    private let injectedVM: BodyViewModel?
    @State private var vm: BodyViewModel?
    @State private var showLogMeasurement = false

    init(viewModel: BodyViewModel? = nil) {
        self.injectedVM = viewModel
        self._vm = State(initialValue: viewModel)
    }

    // MARK: - Grid

    private let tileColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        bodyCompositionSection
                        scanHistoryCard
                            .padding(.horizontal, CadreSpacing.sheetHorizontal)
                            .padding(.top, 12)
                        measurementsSection
                    }
                    .padding(.bottom, 24)
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
            guard injectedVM == nil, vm == nil else { return }
            vm = BodyViewModel(modelContext: modelContext)
            vm?.refresh()
        }
        .sheet(isPresented: $showLogMeasurement) {
            LogMeasurementSheet(viewModel: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Body Composition

    private var bodyCompositionSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Body Composition",
                meta: scanMetaText,
                action: {
                    // TODO: Task 17 — open scan entry flow
                }
            )

            if let tiles = bodyCompTiles, !tiles.isEmpty {
                LazyVGrid(columns: tileColumns, spacing: 8) {
                    ForEach(tiles, id: \.label) { tile in
                        Button {
                            // TODO: navigate to Trends with this metric pre-selected
                            // (Trends multi-metric switching is future work)
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
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
            }
        }
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
                LazyVGrid(columns: tileColumns, spacing: 8) {
                    ForEach(tiles, id: \.label) { tile in
                        Button {
                            // TODO: navigate to Trends with this metric pre-selected
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
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
            }
        }
    }

    // MARK: - Scan History Card

    private var scanHistoryCard: some View {
        NavigationLink {
            // TODO: Task 17 follow-up — scan history list
            scanHistoryPlaceholder
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
            .background(CadreColors.card)
            .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
        }
        .buttonStyle(.plain)
    }

    private var scanHistoryPlaceholder: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(CadreColors.textTertiary)
                Text("Scan history coming soon")
                    .font(CadreTypography.footnote)
                    .foregroundStyle(CadreColors.textTertiary)
            }
        }
        .navigationTitle("Scans")
        .navigationBarTitleDisplayMode(.inline)
    }

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
        guard let scan = vm?.recentScans.first,
              let content = vm?.decodedPayload(for: scan) else { return nil }

        switch content {
        case .inBody(let p):
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
                value: String(format: "%.1f", p.skeletalMuscleMassKg),
                unit: "kg",
                delta: nil
            ))
            tiles.append(TileData(
                sfSymbol: "scalemass",
                label: "Fat Mass",
                value: String(format: "%.1f", p.bodyFatMassKg),
                unit: "kg",
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
                tiles.append(TileData(
                    sfSymbol: "figure.stand",
                    label: "Lean Body Mass",
                    value: String(format: "%.1f", lbm),
                    unit: "kg",
                    delta: nil
                ))
            }
            return tiles
        }
    }

    /// Build tile data from latest tape measurements (only metrics with data).
    /// Ordered by `MeasurementType.allCases` for consistent display.
    private var measurementTiles: [TileData] {
        guard let measurements = vm?.latestMeasurements else { return [] }
        let byType = Dictionary(grouping: measurements) { $0.type }
        return MeasurementType.allCases.compactMap { type -> TileData? in
            guard let m = byType[type.rawValue]?.first else { return nil }
            // Display in inches for now (conversion: cm -> in)
            let inches = m.valueCm / 2.54
            return TileData(
                sfSymbol: type.sfSymbol,
                label: type.tileLabel,
                value: String(format: "%.1f", inches),
                unit: "in",
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
