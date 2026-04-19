import SwiftUI
import SwiftData

/// Detail view for a single scan — shows all decoded payload fields grouped by category.
/// Kebab menu (ellipsis) in toolbar with Edit / Delete actions per design decisions.
struct ScanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Track unit preference so SwiftUI re-renders when it changes
    @AppStorage("weightUnit") private var weightUnit = "lb"

    let scan: Scan
    var onDelete: ((Scan) -> Void)?

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var content: ScanContent? {
        try? scan.decoded()
    }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            if let content {
                ScrollView {
                    VStack(spacing: 0) {
                        switch content {
                        case .inBody(let payload):
                            inBodySections(payload)
                        }
                    }
                    .padding(.bottom, CadreSpacing.xl)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(CadreColors.textTertiary)
                    Text("Unable to decode scan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .navigationTitle(scanTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
        }
        .alert("Delete Scan", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete?(scan)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This scan and all its data will be permanently deleted.")
        }
        .sheet(isPresented: $showEdit) {
            if let content {
                switch content {
                case .inBody(let payload):
                    ScanEditView(scan: scan, payload: payload)
                }
            }
        }
    }

    private var scanTitle: String {
        switch scan.scanType {
        case .inBody: return "InBody 570"
        case .none: return "Scan"
        }
    }

    // MARK: - InBody Sections

    @ViewBuilder
    private func inBodySections(_ p: InBodyPayload) -> some View {
        // Date header
        VStack(spacing: 4) {
            Text(DateFormatting.fullDate(scan.date))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)

        detailSection("Core") {
            massRow("Weight", value: p.weightKg)
            massRow("Skeletal Muscle Mass", value: p.skeletalMuscleMassKg)
            massRow("Body Fat Mass", value: p.bodyFatMassKg)
            detailRow("Body Fat", value: fmt(p.bodyFatPct), unit: "%")
            detailRow("Total Body Water", value: fmt(p.totalBodyWaterL), unit: "L")
            detailRow("BMI", value: fmt(p.bmi), unit: "")
            detailRow("Basal Metabolic Rate", value: String(format: "%.0f", p.basalMetabolicRate), unit: "kcal")
        }

        detailSection("Body Composition") {
            optionalRow("Intracellular Water", value: p.intracellularWaterL, unit: "L")
            optionalRow("Extracellular Water", value: p.extracellularWaterL, unit: "L")
            optionalMassRow("Dry Lean Mass", value: p.dryLeanMassKg)
            optionalMassRow("Lean Body Mass", value: p.leanBodyMassKg)
            optionalRow("InBody Score", value: p.inBodyScore, unit: "")
            optionalRow("ECW/TBW Ratio", value: p.ecwTbwRatio, unit: "")
        }

        detailSection("Additional Metrics") {
            optionalRow("Skeletal Muscle Index", value: p.skeletalMuscleIndex, unit: "kg/m²")
            optionalRow("Visceral Fat Level", value: p.visceralFatLevel, unit: "")
        }

        detailSection("Segmental Lean") {
            optionalMassWithPctRow("Right Arm", mass: p.rightArmLeanKg, pct: p.rightArmLeanPct)
            optionalMassWithPctRow("Left Arm", mass: p.leftArmLeanKg, pct: p.leftArmLeanPct)
            optionalMassWithPctRow("Trunk", mass: p.trunkLeanKg, pct: p.trunkLeanPct)
            optionalMassWithPctRow("Right Leg", mass: p.rightLegLeanKg, pct: p.rightLegLeanPct)
            optionalMassWithPctRow("Left Leg", mass: p.leftLegLeanKg, pct: p.leftLegLeanPct)
        }

        detailSection("Segmental Fat") {
            optionalMassWithPctRow("Right Arm", mass: p.rightArmFatKg, pct: p.rightArmFatPct)
            optionalMassWithPctRow("Left Arm", mass: p.leftArmFatKg, pct: p.leftArmFatPct)
            optionalMassWithPctRow("Trunk", mass: p.trunkFatKg, pct: p.trunkFatPct)
            optionalMassWithPctRow("Right Leg", mass: p.rightLegFatKg, pct: p.rightLegFatPct)
            optionalMassWithPctRow("Left Leg", mass: p.leftLegFatKg, pct: p.leftLegFatPct)
        }
    }

    // MARK: - Section & Row Helpers

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(CadreColors.textTertiary)
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    private func detailRow(_ label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CadreColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    /// Row for mass values (kg) that converts based on user's weight unit preference.
    private func massRow(_ label: String, value: Double) -> some View {
        _ = weightUnit  // SwiftUI dependency: re-render when unit preference changes
        let display = UnitConversion.formattedMass(value)
        return detailRow(label, value: display.text, unit: display.unit)
    }

    /// Optional mass row — only shows if value is non-nil, with unit conversion.
    @ViewBuilder
    private func optionalMassRow(_ label: String, value: Double?) -> some View {
        if let value {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(CadreColors.divider)
                    .frame(height: 0.5)
                massRow(label, value: value)
            }
        }
    }

    @ViewBuilder
    private func optionalRow(_ label: String, value: Double?, unit: String) -> some View {
        if let value {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(CadreColors.divider)
                    .frame(height: 0.5)
                detailRow(label, value: fmt(value), unit: unit)
            }
        }
    }

    /// Optional mass row that appends a sufficiency percentage as a secondary value when available.
    /// Shows: "Right Arm    7.94 lb · 112.4%"
    @ViewBuilder
    private func optionalMassWithPctRow(_ label: String, mass: Double?, pct: Double?) -> some View {
        if let mass {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(CadreColors.divider)
                    .frame(height: 0.5)
                HStack {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        let display = UnitConversion.formattedMass(mass)
                        Text(display.text)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(CadreColors.textPrimary)
                        Text(display.unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                        if let pct {
                            Text("·")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CadreColors.textTertiary)
                            Text(String(format: "%.1f%%", pct))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(CadreColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }
        }
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Scan Edit View

/// Edit sheet for an existing scan. Renders the same manual form used for new
/// scans by seeding a `ScanEntryViewModel` with the scan's payload and letting
/// `ScanEntryFlow` drive the UI. Unit conversion, save, and overwrite handling
/// all live in the view model so entry and edit can never visually drift.
struct ScanEditView: View {
    @Environment(\.modelContext) private var modelContext

    let scan: Scan
    let payload: InBodyPayload

    @State private var vm: ScanEntryViewModel?

    var body: some View {
        Group {
            if let vm {
                ScanEntryFlow(viewModel: vm)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if vm == nil {
                let pref = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
                let newVM = ScanEntryViewModel(modelContext: modelContext)
                newVM.loadForEdit(scan: scan, payload: payload, massPref: pref)
                vm = newVM
            }
        }
    }
}
