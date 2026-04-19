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
        dateChip
            .padding(.top, 12)

        sectionLabel("Body Composition Analysis")
        optRow("Intracellular Water (ICW)", value: p.intracellularWaterL, unit: "L")
        optRow("Extracellular Water (ECW)", value: p.extracellularWaterL, unit: "L")
        row("Total Body Water (TBW)", value: fmt(p.totalBodyWaterL), unit: "L")
        optMassRow("Dry Lean Mass", kg: p.dryLeanMassKg)
        optMassRow("Lean Body Mass (LBM)", kg: p.leanBodyMassKg)
        massRow("Body Fat Mass", kg: p.bodyFatMassKg)

        sectionLabel("Muscle-Fat Analysis")
        massRow("Weight", kg: p.weightKg)
        massRow("Skeletal Muscle Mass (SMM)", kg: p.skeletalMuscleMassKg)

        sectionLabel("Obesity Analysis")
        row("BMI", value: fmt(p.bmi), unit: "kg/m\u{00B2}")
        row("Body Fat % (PBF)", value: fmt(p.bodyFatPct), unit: "%")

        sectionLabel("Segmental Lean Analysis")
        segmentalTableHeader()
        segmentalRow("Right Arm", mass: p.rightArmLeanKg, pct: p.rightArmLeanPct)
        segmentalRow("Left Arm", mass: p.leftArmLeanKg, pct: p.leftArmLeanPct)
        segmentalRow("Trunk", mass: p.trunkLeanKg, pct: p.trunkLeanPct)
        segmentalRow("Right Leg", mass: p.rightLegLeanKg, pct: p.rightLegLeanPct)
        segmentalRow("Left Leg", mass: p.leftLegLeanKg, pct: p.leftLegLeanPct)

        if p.ecwTbwRatio != nil {
            sectionLabel("ECW/TBW Analysis")
            optRow("Ratio", value: p.ecwTbwRatio, unit: "", format: { String(format: "%.3f", $0) })
        }

        sectionLabel("Segmental Fat Analysis")
        segmentalTableHeader()
        segmentalRow("Right Arm", mass: p.rightArmFatKg, pct: p.rightArmFatPct)
        segmentalRow("Left Arm", mass: p.leftArmFatKg, pct: p.leftArmFatPct)
        segmentalRow("Trunk", mass: p.trunkFatKg, pct: p.trunkFatPct)
        segmentalRow("Right Leg", mass: p.rightLegFatKg, pct: p.rightLegFatPct)
        segmentalRow("Left Leg", mass: p.leftLegFatKg, pct: p.leftLegFatPct)

        sectionLabel("Additional Metrics")
        row("Basal Metabolic Rate (BMR)", value: String(format: "%.0f", p.basalMetabolicRate), unit: "kcal")
        optRow("Skeletal Muscle Index (SMI)", value: p.skeletalMuscleIndex, unit: "kg/m\u{00B2}")
        optRow("Visceral Fat Level", value: p.visceralFatLevel, unit: "", format: { String(format: "%.0f", $0) })
        optRow("InBody Score", value: p.inBodyScore, unit: "", format: { String(format: "%.0f", $0) })
    }

    // MARK: - Date Chip (read-only pill matching entry/edit's interactive chip)

    private var dateChip: some View {
        Text(DateFormatting.fullDate(scan.date))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(CadreColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(CadreColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: CadreRadius.full)
                    .stroke(CadreColors.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CadreRadius.full))
    }

    // MARK: - Section & Row Helpers (read-only mirrors of ScanEntryFlow.reviewRow/segmentalRow)

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(CadreColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func row(_ label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .tracking(-0.2)
                    .foregroundStyle(CadreColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CadreColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(CadreColors.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .frame(width: 120)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func optRow(_ label: String, value: Double?, unit: String, format: (Double) -> String = { String(format: "%.1f", $0) }) -> some View {
        if let value {
            row(label, value: format(value), unit: unit)
        }
    }

    /// Mass row — converts from stored kg to user's preferred unit.
    private func massRow(_ label: String, kg: Double) -> some View {
        _ = weightUnit  // SwiftUI dependency: re-render when unit preference changes
        let display = UnitConversion.formattedMass(kg)
        return row(label, value: display.text, unit: display.unit)
    }

    @ViewBuilder
    private func optMassRow(_ label: String, kg: Double?) -> some View {
        if let kg {
            massRow(label, kg: kg)
        }
    }

    // MARK: - Segmental Table

    private func segmentalTableHeader() -> some View {
        HStack {
            Text("Segment")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Mass")
                .frame(width: 92, alignment: .center)
            Text("Suff. %")
                .frame(width: 78, alignment: .center)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(CadreColors.textTertiary)
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.bottom, 6)
    }

    private func segmentalRow(_ segment: String, mass: Double?, pct: Double?) -> some View {
        _ = weightUnit
        return HStack(spacing: 6) {
            Text(segment)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            segmentalCell(
                valueText: mass.map { UnitConversion.formattedMass($0).text } ?? "",
                unit: mass.map { UnitConversion.formattedMass($0).unit } ?? ""
            )
            .frame(width: 92)

            segmentalCell(
                valueText: pct.map { String(format: "%.1f", $0) } ?? "",
                unit: pct == nil ? "" : "%"
            )
            .frame(width: 78)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 3)
    }

    private func segmentalCell(valueText: String, unit: String) -> some View {
        let isMissing = valueText.isEmpty
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(isMissing ? "—" : valueText)
                .font(.system(size: 13, weight: .bold, design: .default))
                .tracking(-0.2)
                .foregroundStyle(isMissing ? CadreColors.textTertiary : CadreColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(CadreColors.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isMissing ? CadreColors.textTertiary : CadreColors.divider,
                    style: isMissing ? StrokeStyle(lineWidth: 1, dash: [4, 3]) : StrokeStyle(lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
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
