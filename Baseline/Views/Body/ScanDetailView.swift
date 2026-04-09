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

    // New fields (Task 1 expansion)
    @State private var ecwTbwRatio: String
    @State private var skeletalMuscleIndex: String
    @State private var visceralFatLevel: String
    @State private var rightArmLeanPct: String
    @State private var leftArmLeanPct: String
    @State private var trunkLeanPct: String
    @State private var rightLegLeanPct: String
    @State private var leftLegLeanPct: String
    @State private var rightArmFatPct: String
    @State private var leftArmFatPct: String
    @State private var trunkFatPct: String
    @State private var rightLegFatPct: String
    @State private var leftLegFatPct: String

    @State private var errorMessage: String?

    /// User's preferred mass unit — read once at init so the form is consistent.
    private let massPref: String

    /// Display label for mass fields ("kg" or "lb").
    private var massUnit: String { massPref }

    init(scan: Scan, payload: InBodyPayload) {
        self.scan = scan
        self.payload = payload

        let pref = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        self.massPref = pref

        // Convert kg → display unit for mass fields
        let m: (Double) -> String = { kg in
            Self.fmt(pref == "kg" ? kg : UnitConversion.kgToLb(kg))
        }
        let om: (Double?) -> String = { kg in
            guard let kg else { return "" }
            return Self.fmt(pref == "kg" ? kg : UnitConversion.kgToLb(kg))
        }

        _weightKg = State(initialValue: m(payload.weightKg))
        _skeletalMuscleMassKg = State(initialValue: m(payload.skeletalMuscleMassKg))
        _bodyFatMassKg = State(initialValue: m(payload.bodyFatMassKg))
        _bodyFatPct = State(initialValue: Self.fmt(payload.bodyFatPct))
        _totalBodyWaterL = State(initialValue: Self.fmt(payload.totalBodyWaterL))
        _bmi = State(initialValue: Self.fmt(payload.bmi))
        _basalMetabolicRate = State(initialValue: Self.fmt(payload.basalMetabolicRate))
        _intracellularWaterL = State(initialValue: Self.optFmt(payload.intracellularWaterL))
        _extracellularWaterL = State(initialValue: Self.optFmt(payload.extracellularWaterL))
        _dryLeanMassKg = State(initialValue: om(payload.dryLeanMassKg))
        _leanBodyMassKg = State(initialValue: om(payload.leanBodyMassKg))
        _inBodyScore = State(initialValue: Self.optFmt(payload.inBodyScore))
        _rightArmLeanKg = State(initialValue: om(payload.rightArmLeanKg))
        _leftArmLeanKg = State(initialValue: om(payload.leftArmLeanKg))
        _trunkLeanKg = State(initialValue: om(payload.trunkLeanKg))
        _rightLegLeanKg = State(initialValue: om(payload.rightLegLeanKg))
        _leftLegLeanKg = State(initialValue: om(payload.leftLegLeanKg))
        _rightArmFatKg = State(initialValue: om(payload.rightArmFatKg))
        _leftArmFatKg = State(initialValue: om(payload.leftArmFatKg))
        _trunkFatKg = State(initialValue: om(payload.trunkFatKg))
        _rightLegFatKg = State(initialValue: om(payload.rightLegFatKg))
        _leftLegFatKg = State(initialValue: om(payload.leftLegFatKg))

        _ecwTbwRatio = State(initialValue: Self.optFmt(payload.ecwTbwRatio))
        _skeletalMuscleIndex = State(initialValue: Self.optFmt(payload.skeletalMuscleIndex))
        _visceralFatLevel = State(initialValue: Self.optFmt(payload.visceralFatLevel))
        _rightArmLeanPct = State(initialValue: Self.optFmt(payload.rightArmLeanPct))
        _leftArmLeanPct = State(initialValue: Self.optFmt(payload.leftArmLeanPct))
        _trunkLeanPct = State(initialValue: Self.optFmt(payload.trunkLeanPct))
        _rightLegLeanPct = State(initialValue: Self.optFmt(payload.rightLegLeanPct))
        _leftLegLeanPct = State(initialValue: Self.optFmt(payload.leftLegLeanPct))
        _rightArmFatPct = State(initialValue: Self.optFmt(payload.rightArmFatPct))
        _leftArmFatPct = State(initialValue: Self.optFmt(payload.leftArmFatPct))
        _trunkFatPct = State(initialValue: Self.optFmt(payload.trunkFatPct))
        _rightLegFatPct = State(initialValue: Self.optFmt(payload.rightLegFatPct))
        _leftLegFatPct = State(initialValue: Self.optFmt(payload.leftLegFatPct))
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
            formRow("Weight", value: $weightKg, unit: massUnit)
            formRow("Body Fat", value: $bodyFatPct, unit: "%")
            formRow("Skeletal Muscle", value: $skeletalMuscleMassKg, unit: massUnit)
            formRow("Body Fat Mass", value: $bodyFatMassKg, unit: massUnit)
            formRow("BMI", value: $bmi, unit: "")
            formRow("BMR", value: $basalMetabolicRate, unit: "kcal")
            formRow("Total Body Water", value: $totalBodyWaterL, unit: "L")

            formSectionLabel("Body Composition")
            formRow("Intracellular Water", value: $intracellularWaterL, unit: "L")
            formRow("Extracellular Water", value: $extracellularWaterL, unit: "L")
            formRow("Dry Lean Mass", value: $dryLeanMassKg, unit: massUnit)
            formRow("Lean Body Mass", value: $leanBodyMassKg, unit: massUnit)
            formRow("InBody Score", value: $inBodyScore, unit: "")
            formRow("ECW/TBW Ratio", value: $ecwTbwRatio, unit: "")

            formSectionLabel("Additional Metrics")
            formRow("Skeletal Muscle Index", value: $skeletalMuscleIndex, unit: "kg/m²")
            formRow("Visceral Fat Level", value: $visceralFatLevel, unit: "")

            formSectionLabel("Segmental Lean")
            formRow("Right Arm", value: $rightArmLeanKg, unit: massUnit)
            formRow("Right Arm %", value: $rightArmLeanPct, unit: "%")
            formRow("Left Arm", value: $leftArmLeanKg, unit: massUnit)
            formRow("Left Arm %", value: $leftArmLeanPct, unit: "%")
            formRow("Trunk", value: $trunkLeanKg, unit: massUnit)
            formRow("Trunk %", value: $trunkLeanPct, unit: "%")
            formRow("Right Leg", value: $rightLegLeanKg, unit: massUnit)
            formRow("Right Leg %", value: $rightLegLeanPct, unit: "%")
            formRow("Left Leg", value: $leftLegLeanKg, unit: massUnit)
            formRow("Left Leg %", value: $leftLegLeanPct, unit: "%")

            formSectionLabel("Segmental Fat")
            formRow("Right Arm", value: $rightArmFatKg, unit: massUnit)
            formRow("Right Arm %", value: $rightArmFatPct, unit: "%")
            formRow("Left Arm", value: $leftArmFatKg, unit: massUnit)
            formRow("Left Arm %", value: $leftArmFatPct, unit: "%")
            formRow("Trunk", value: $trunkFatKg, unit: massUnit)
            formRow("Trunk %", value: $trunkFatPct, unit: "%")
            formRow("Right Leg", value: $rightLegFatKg, unit: massUnit)
            formRow("Right Leg %", value: $rightLegFatPct, unit: "%")
            formRow("Left Leg", value: $leftLegFatKg, unit: massUnit)
            formRow("Left Leg %", value: $leftLegFatPct, unit: "%")
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
                .frame(width: 140, alignment: .leading)

            TextField("", text: value)
                .font(.system(size: 15, weight: .bold, design: .default))
                .tracking(-0.2)
                .foregroundStyle(CadreColors.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .frame(width: 30, alignment: .trailing)
            } else {
                Spacer()
                    .frame(width: 30)
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
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Save

    /// Convert a display-unit mass value back to kg for storage.
    private func toKg(_ value: Double) -> Double {
        massPref == "kg" ? value : UnitConversion.lbToKg(value)
    }

    /// Convert an optional display-unit mass string back to kg.
    private func optToKg(_ text: String) -> Double? {
        guard let v = Double(text) else { return nil }
        return toKg(v)
    }

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
            weightKg: toKg(w),
            skeletalMuscleMassKg: toKg(smm),
            bodyFatMassKg: toKg(bfm),
            bodyFatPct: bf,
            totalBodyWaterL: tbw,
            bmi: b,
            basalMetabolicRate: bmrVal,
            intracellularWaterL: Double(intracellularWaterL),
            extracellularWaterL: Double(extracellularWaterL),
            dryLeanMassKg: optToKg(dryLeanMassKg),
            leanBodyMassKg: optToKg(leanBodyMassKg),
            inBodyScore: Double(inBodyScore),
            rightArmLeanKg: optToKg(rightArmLeanKg),
            leftArmLeanKg: optToKg(leftArmLeanKg),
            trunkLeanKg: optToKg(trunkLeanKg),
            rightLegLeanKg: optToKg(rightLegLeanKg),
            leftLegLeanKg: optToKg(leftLegLeanKg),
            rightArmFatKg: optToKg(rightArmFatKg),
            leftArmFatKg: optToKg(leftArmFatKg),
            trunkFatKg: optToKg(trunkFatKg),
            rightLegFatKg: optToKg(rightLegFatKg),
            leftLegFatKg: optToKg(leftLegFatKg),
            ecwTbwRatio: Double(ecwTbwRatio),
            skeletalMuscleIndex: Double(skeletalMuscleIndex),
            visceralFatLevel: Double(visceralFatLevel),
            rightArmLeanPct: Double(rightArmLeanPct),
            leftArmLeanPct: Double(leftArmLeanPct),
            trunkLeanPct: Double(trunkLeanPct),
            rightLegLeanPct: Double(rightLegLeanPct),
            leftLegLeanPct: Double(leftLegLeanPct),
            rightArmFatPct: Double(rightArmFatPct),
            leftArmFatPct: Double(leftArmFatPct),
            trunkFatPct: Double(trunkFatPct),
            rightLegFatPct: Double(rightLegFatPct),
            leftLegFatPct: Double(leftLegFatPct)
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
