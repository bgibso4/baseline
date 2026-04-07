import SwiftUI
import SwiftData

/// Detail view for a single scan — shows all decoded payload fields grouped by category.
/// Kebab menu (ellipsis) in toolbar with Edit / Delete actions per design decisions.
struct ScanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let scan: Scan
    var onDelete: ((Scan) -> Void)?

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var content: ScanContent? {
        try? scan.decoded()
    }

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

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
        .toolbarBackground(CadreColors.bg, for: .navigationBar)
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
        }

        detailSection("Segmental Lean") {
            optionalMassRow("Right Arm", value: p.rightArmLeanKg)
            optionalMassRow("Left Arm", value: p.leftArmLeanKg)
            optionalMassRow("Trunk", value: p.trunkLeanKg)
            optionalMassRow("Right Leg", value: p.rightLegLeanKg)
            optionalMassRow("Left Leg", value: p.leftLegLeanKg)
        }

        detailSection("Segmental Fat") {
            optionalMassRow("Right Arm", value: p.rightArmFatKg)
            optionalMassRow("Left Arm", value: p.leftArmFatKg)
            optionalMassRow("Trunk", value: p.trunkFatKg)
            optionalMassRow("Right Leg", value: p.rightLegFatKg)
            optionalMassRow("Left Leg", value: p.leftLegFatKg)
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

    private func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Scan Edit View

/// Edit sheet for an existing scan — same form layout as manual scan entry,
/// pre-populated with existing payload values. Save re-encodes and updates the Scan record.
struct ScanEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let scan: Scan
    let payload: InBodyPayload

    // Editable string fields (mirrors ScanEntryViewModel fields)
    @State private var weightKg: String
    @State private var skeletalMuscleMassKg: String
    @State private var bodyFatMassKg: String
    @State private var bodyFatPct: String
    @State private var totalBodyWaterL: String
    @State private var bmi: String
    @State private var basalMetabolicRate: String
    @State private var intracellularWaterL: String
    @State private var extracellularWaterL: String
    @State private var dryLeanMassKg: String
    @State private var leanBodyMassKg: String
    @State private var inBodyScore: String
    @State private var rightArmLeanKg: String
    @State private var leftArmLeanKg: String
    @State private var trunkLeanKg: String
    @State private var rightLegLeanKg: String
    @State private var leftLegLeanKg: String
    @State private var rightArmFatKg: String
    @State private var leftArmFatKg: String
    @State private var trunkFatKg: String
    @State private var rightLegFatKg: String
    @State private var leftLegFatKg: String

    @State private var errorMessage: String?

    init(scan: Scan, payload: InBodyPayload) {
        self.scan = scan
        self.payload = payload
        // Pre-populate all fields from the existing payload
        _weightKg = State(initialValue: Self.fmt(payload.weightKg))
        _skeletalMuscleMassKg = State(initialValue: Self.fmt(payload.skeletalMuscleMassKg))
        _bodyFatMassKg = State(initialValue: Self.fmt(payload.bodyFatMassKg))
        _bodyFatPct = State(initialValue: Self.fmt(payload.bodyFatPct))
        _totalBodyWaterL = State(initialValue: Self.fmt(payload.totalBodyWaterL))
        _bmi = State(initialValue: Self.fmt(payload.bmi))
        _basalMetabolicRate = State(initialValue: Self.fmt(payload.basalMetabolicRate))
        _intracellularWaterL = State(initialValue: Self.optFmt(payload.intracellularWaterL))
        _extracellularWaterL = State(initialValue: Self.optFmt(payload.extracellularWaterL))
        _dryLeanMassKg = State(initialValue: Self.optFmt(payload.dryLeanMassKg))
        _leanBodyMassKg = State(initialValue: Self.optFmt(payload.leanBodyMassKg))
        _inBodyScore = State(initialValue: Self.optFmt(payload.inBodyScore))
        _rightArmLeanKg = State(initialValue: Self.optFmt(payload.rightArmLeanKg))
        _leftArmLeanKg = State(initialValue: Self.optFmt(payload.leftArmLeanKg))
        _trunkLeanKg = State(initialValue: Self.optFmt(payload.trunkLeanKg))
        _rightLegLeanKg = State(initialValue: Self.optFmt(payload.rightLegLeanKg))
        _leftLegLeanKg = State(initialValue: Self.optFmt(payload.leftLegLeanKg))
        _rightArmFatKg = State(initialValue: Self.optFmt(payload.rightArmFatKg))
        _leftArmFatKg = State(initialValue: Self.optFmt(payload.leftArmFatKg))
        _trunkFatKg = State(initialValue: Self.optFmt(payload.trunkFatKg))
        _rightLegFatKg = State(initialValue: Self.optFmt(payload.rightLegFatKg))
        _leftLegFatKg = State(initialValue: Self.optFmt(payload.leftLegFatKg))
    }

    private var canSave: Bool {
        !weightKg.isEmpty &&
        !skeletalMuscleMassKg.isEmpty &&
        !bodyFatMassKg.isEmpty &&
        !bodyFatPct.isEmpty &&
        !totalBodyWaterL.isEmpty &&
        !bmi.isEmpty &&
        !basalMetabolicRate.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Date display
                            Text(DateFormatting.fullDate(scan.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(CadreColors.textSecondary)
                                .padding(.top, 16)

                            editFormFields
                        }
                    }

                    // Save button
                    Button {
                        saveEdits()
                    } label: {
                        Text("Save")
                            .font(CadreTypography.buttonLabel)
                            .tracking(0.3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(canSave ? CadreColors.accent : CadreColors.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Edit Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            .toolbarBackground(CadreColors.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Form Fields

    private var editFormFields: some View {
        VStack(spacing: 0) {
            formSectionLabel("Core")
            formRow("Weight", value: $weightKg, unit: "kg")
            formRow("Body Fat", value: $bodyFatPct, unit: "%")
            formRow("Skeletal Muscle", value: $skeletalMuscleMassKg, unit: "kg")
            formRow("Body Fat Mass", value: $bodyFatMassKg, unit: "kg")
            formRow("BMI", value: $bmi, unit: "")
            formRow("BMR", value: $basalMetabolicRate, unit: "kcal")
            formRow("Total Body Water", value: $totalBodyWaterL, unit: "L")

            formSectionLabel("Body Composition")
            formRow("Intracellular Water", value: $intracellularWaterL, unit: "L")
            formRow("Extracellular Water", value: $extracellularWaterL, unit: "L")
            formRow("Dry Lean Mass", value: $dryLeanMassKg, unit: "kg")
            formRow("Lean Body Mass", value: $leanBodyMassKg, unit: "kg")
            formRow("InBody Score", value: $inBodyScore, unit: "")

            formSectionLabel("Segmental Lean")
            formRow("Right Arm", value: $rightArmLeanKg, unit: "kg")
            formRow("Left Arm", value: $leftArmLeanKg, unit: "kg")
            formRow("Trunk", value: $trunkLeanKg, unit: "kg")
            formRow("Right Leg", value: $rightLegLeanKg, unit: "kg")
            formRow("Left Leg", value: $leftLegLeanKg, unit: "kg")

            formSectionLabel("Segmental Fat")
            formRow("Right Arm", value: $rightArmFatKg, unit: "kg")
            formRow("Left Arm", value: $leftArmFatKg, unit: "kg")
            formRow("Trunk", value: $trunkFatKg, unit: "kg")
            formRow("Right Leg", value: $rightLegFatKg, unit: "kg")
            formRow("Left Leg", value: $leftLegFatKg, unit: "kg")
        }
        .padding(.bottom, 16)
    }

    private func formSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(CadreColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private func formRow(_ label: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.textPrimary)

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("", text: value)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .tracking(-0.2)
                    .foregroundStyle(CadreColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 50)

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
            .frame(minWidth: 92)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Save

    private func saveEdits() {
        guard let w = Double(weightKg),
              let smm = Double(skeletalMuscleMassKg),
              let bfm = Double(bodyFatMassKg),
              let bf = Double(bodyFatPct),
              let tbw = Double(totalBodyWaterL),
              let b = Double(bmi),
              let bmrVal = Double(basalMetabolicRate) else {
            return
        }

        let updated = InBodyPayload(
            weightKg: w,
            skeletalMuscleMassKg: smm,
            bodyFatMassKg: bfm,
            bodyFatPct: bf,
            totalBodyWaterL: tbw,
            bmi: b,
            basalMetabolicRate: bmrVal,
            intracellularWaterL: Double(intracellularWaterL),
            extracellularWaterL: Double(extracellularWaterL),
            dryLeanMassKg: Double(dryLeanMassKg),
            leanBodyMassKg: Double(leanBodyMassKg),
            inBodyScore: Double(inBodyScore),
            rightArmLeanKg: Double(rightArmLeanKg),
            leftArmLeanKg: Double(leftArmLeanKg),
            trunkLeanKg: Double(trunkLeanKg),
            rightLegLeanKg: Double(rightLegLeanKg),
            leftLegLeanKg: Double(leftLegLeanKg),
            rightArmFatKg: Double(rightArmFatKg),
            leftArmFatKg: Double(leftArmFatKg),
            trunkFatKg: Double(trunkFatKg),
            rightLegFatKg: Double(rightLegFatKg),
            leftLegFatKg: Double(leftLegFatKg)
        )

        guard let data = try? JSONEncoder().encode(updated) else { return }
        scan.payloadData = data
        scan.updatedAt = Date()
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    // MARK: - Formatting Helpers

    private static func fmt(_ value: Double) -> String {
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static func optFmt(_ value: Double?) -> String {
        guard let value else { return "" }
        return fmt(value)
    }
}
