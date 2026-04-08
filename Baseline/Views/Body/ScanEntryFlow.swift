import SwiftUI
import SwiftData

/// Multi-step scan entry flow — 5 screens driven by `ScanEntryViewModel`.
///
/// Visual target: `docs/mockups/scan-entry-flow-2026-04-05.html`
///
/// Flow: Scan Type -> Input Method -> (Camera -> Review) OR Manual Entry -> Save.
/// In v1, only InBody 570 is supported.
struct ScanEntryFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let injectedVM: ScanEntryViewModel?
    @State private var vm: ScanEntryViewModel?

    init(viewModel: ScanEntryViewModel? = nil) {
        self.injectedVM = viewModel
    }

    private var resolvedVM: ScanEntryViewModel? {
        vm ?? injectedVM
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                if let vm = resolvedVM {
                    // AnyView breaks the type metadata chain — without it, the
                    // combined type of all 5 steps causes a stack overflow in
                    // Swift's type decoder on ARM devices.
                    switch vm.currentStep {
                    case .selectType:
                        AnyView(scanTypeStep(vm: vm))
                    case .selectMethod:
                        AnyView(inputMethodStep(vm: vm))
                    case .camera:
                        AnyView(cameraStep(vm: vm))
                    case .review:
                        AnyView(reviewFormStep(vm: vm))
                    case .manualEntry:
                        AnyView(manualFormStep(vm: vm))
                    }
                }
            }
        }
        .onAppear {
            if injectedVM == nil, vm == nil {
                vm = ScanEntryViewModel(modelContext: modelContext)
            }
        }
    }

    // MARK: - Step 1: Scan Type Selection

    private func scanTypeStep(vm: ScanEntryViewModel) -> some View {
        VStack(spacing: 0) {
            pushHeader(title: "New Scan", subtitle: "Step 1 of 2") {
                dismiss()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Intro text
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What type of scan?")
                            .font(.system(size: 22, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(CadreColors.textPrimary)
                        Text("Each machine records a different set of metrics.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    // InBody 570 card (pre-selected)
                    scanTypeCard(
                        icon: "570",
                        name: "InBody 570",
                        description: "Body comp \u{00B7} segmental lean \u{00B7} water analysis",
                        isSelected: vm.selectedType == .inBody
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)

                    // "More coming soon" note
                    comingSoonNote
                        .padding(.horizontal, CadreSpacing.sheetHorizontal)
                        .padding(.top, 14)
                }
            }

            // Continue button at bottom
            continueButton(label: "Continue") {
                vm.selectType(.inBody)
            }
        }
    }

    private func scanTypeCard(icon: String, name: String, description: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Icon
            Text(icon)
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(-0.2)
                .foregroundStyle(CadreColors.accent)
                .frame(width: 36, height: 36)
                .background(isSelected ? CadreColors.accent.opacity(0.2) : CadreColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(CadreColors.textPrimary)
                Text(description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(isSelected ? CadreColors.cardElevated : CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? CadreColors.accent : CadreColors.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var comingSoonNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.textTertiary)
            Text("More scan types coming soon")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CadreColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(CadreColors.divider, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Step 2: Input Method

    private func inputMethodStep(vm: ScanEntryViewModel) -> some View {
        VStack(spacing: 0) {
            pushHeader(title: "New Scan", subtitle: "Step 2 of 2") {
                vm.goBack()
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("How do you want to enter it?")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(CadreColors.textPrimary)
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                VStack(spacing: 12) {
                    methodCard(
                        icon: "camera",
                        title: "Scan printout",
                        description: "Point camera at InBody printout. Values read automatically, you review before saving."
                    ) {
                        vm.selectMethod(camera: true)
                    }

                    methodCard(
                        icon: "square.and.pencil",
                        title: "Enter manually",
                        description: "Type the values from your printout yourself."
                    ) {
                        vm.selectMethod(camera: false)
                    }
                }
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 20)
            }

            Spacer()
        }
    }

    private func methodCard(icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(CadreColors.accent)
                    .frame(width: 44, height: 44)
                    .background(CadreColors.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)
                    .frame(height: 44)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .background(CadreColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(CadreColors.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Camera

    private func cameraStep(vm: ScanEntryViewModel) -> some View {
        ZStack {
            DocumentScannerView(
                onScan: { scan in
                    Task {
                        await vm.processScan(scan)
                    }
                },
                onCancel: {
                    vm.goBack()
                }
            )
            .ignoresSafeArea()

            if vm.isProcessing {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(CadreColors.accent)
                    Text("Reading scan...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                }
            }
        }
    }

    // MARK: - Step 4: Review Form (post-OCR)

    @State private var showDatePicker: Bool = false

    private func reviewFormStep(vm: ScanEntryViewModel) -> some View {
        @Bindable var bvm = vm
        return ZStack {
            VStack(spacing: 0) {
                reviewHeader(vm: vm)

                ScrollView {
                    VStack(spacing: 0) {
                        reviewDateChip(vm: vm)
                            .padding(.top, 12)

                        // Warning banner: N fields may need review
                        if !vm.lowConfidenceFields.isEmpty {
                            warningBanner(count: vm.lowConfidenceFields.count)
                                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                                .padding(.top, 12)
                        }

                        // Retry banner: some fields couldn't be read
                        if hasEmptyRequiredField(vm: vm) {
                            retryBanner(vm: vm)
                                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                                .padding(.top, 8)
                        }

                        reviewFields(vm: vm)
                    }
                }

                // Save button
                reviewSaveButton(vm: vm)
            }

            // Date picker overlay
            if showDatePicker {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showDatePicker = false }
                    }

                VStack {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { vm.scanDate ?? Date() },
                            set: { vm.scanDate = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(CadreColors.accent)
                    .labelsHidden()
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(CadreColors.card)
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func reviewHeader(vm: ScanEntryViewModel) -> some View {
        HStack(spacing: 12) {
            Button {
                vm.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(CadreColors.cardElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Review Scan")
                .font(.system(size: 17, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(CadreColors.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func reviewDateChipLabel(vm: ScanEntryViewModel) -> String {
        guard let date = vm.scanDate else { return "Today" }
        if DateFormatting.isToday(date) { return "Today" }
        return DateFormatting.fullDate(date)
    }

    private func reviewDateChip(vm: ScanEntryViewModel) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showDatePicker.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(reviewDateChipLabel(vm: vm))
                    .font(CadreTypography.dateChip)
                    .foregroundStyle(CadreColors.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(CadreColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: CadreRadius.full)
                    .stroke(CadreColors.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CadreRadius.full))
        }
        .buttonStyle(.plain)
        .onChange(of: vm.scanDate) { _, _ in
            withAnimation { showDatePicker = false }
        }
    }

    // MARK: - Warning / Retry Banners

    private let amberColor = Color(hex: "B89968")

    private func warningBanner(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(amberColor)
            Text("\(count) field\(count == 1 ? "" : "s") may need review")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(amberColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(amberColor.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(amberColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func hasEmptyRequiredField(vm: ScanEntryViewModel) -> Bool {
        vm.weightKg.isEmpty ||
        vm.skeletalMuscleMassKg.isEmpty ||
        vm.bodyFatMassKg.isEmpty ||
        vm.bodyFatPct.isEmpty ||
        vm.totalBodyWaterL.isEmpty ||
        vm.bmi.isEmpty ||
        vm.basalMetabolicRate.isEmpty
    }

    private func retryBanner(vm: ScanEntryViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(amberColor)

            Text("Some fields couldn\u{2019}t be read")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(amberColor)

            Spacer()

            Button {
                vm.retryCount += 1
                vm.currentStep = .camera
            } label: {
                Text("Retry Scan")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(amberColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(amberColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(amberColor.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(amberColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Field Binding Helper

    /// Creates a Binding<String> to a field in the VM's fields dictionary.
    private func fieldBinding(_ key: String, vm: ScanEntryViewModel) -> Binding<String> {
        Binding(
            get: { vm.fields[key, default: ""] },
            set: { vm.fields[key] = $0 }
        )
    }

    // MARK: - Review Fields (ordered to mirror InBody 570 printout)

    private func reviewFields(vm: ScanEntryViewModel) -> some View {
        VStack(spacing: 0) {
            // Body Composition Analysis
            reviewSectionLabel("Body Composition Analysis")
            reviewRow("ICW", value: fieldBinding("intracellularWaterL", vm: vm), unit: "L", key: "intracellularWaterL", vm: vm)
            reviewRow("ECW", value: fieldBinding("extracellularWaterL", vm: vm), unit: "L", key: "extracellularWaterL", vm: vm)
            reviewRow("TBW", value: fieldBinding("totalBodyWaterL", vm: vm), unit: "L", key: "totalBodyWaterL", vm: vm)
            reviewRow("Dry Lean Mass", value: fieldBinding("dryLeanMassKg", vm: vm), unit: "lbs", key: "dryLeanMassKg", vm: vm)
            reviewRow("LBM", value: fieldBinding("leanBodyMassKg", vm: vm), unit: "lbs", key: "leanBodyMassKg", vm: vm)
            reviewRow("Body Fat Mass", value: fieldBinding("bodyFatMassKg", vm: vm), unit: "lbs", key: "bodyFatMassKg", vm: vm)

            // Muscle-Fat Analysis
            reviewSectionLabel("Muscle-Fat Analysis")
            reviewRow("Weight", value: fieldBinding("weightKg", vm: vm), unit: "lbs", key: "weightKg", vm: vm)
            reviewRow("SMM", value: fieldBinding("skeletalMuscleMassKg", vm: vm), unit: "lbs", key: "skeletalMuscleMassKg", vm: vm)

            // Obesity Analysis
            reviewSectionLabel("Obesity Analysis")
            reviewRow("BMI", value: fieldBinding("bmi", vm: vm), unit: "", key: "bmi", vm: vm)
            reviewRow("PBF", value: fieldBinding("bodyFatPct", vm: vm), unit: "%", key: "bodyFatPct", vm: vm)

            // Segmental Lean Analysis
            reviewSectionLabel("Segmental Lean Analysis")
            segmentalTableHeader()
            segmentalRow("Right Arm", mass: fieldBinding("rightArmLeanKg", vm: vm), massKey: "rightArmLeanKg", pct: fieldBinding("rightArmLeanPct", vm: vm), pctKey: "rightArmLeanPct", vm: vm)
            segmentalRow("Left Arm", mass: fieldBinding("leftArmLeanKg", vm: vm), massKey: "leftArmLeanKg", pct: fieldBinding("leftArmLeanPct", vm: vm), pctKey: "leftArmLeanPct", vm: vm)
            segmentalRow("Trunk", mass: fieldBinding("trunkLeanKg", vm: vm), massKey: "trunkLeanKg", pct: fieldBinding("trunkLeanPct", vm: vm), pctKey: "trunkLeanPct", vm: vm)
            segmentalRow("Right Leg", mass: fieldBinding("rightLegLeanKg", vm: vm), massKey: "rightLegLeanKg", pct: fieldBinding("rightLegLeanPct", vm: vm), pctKey: "rightLegLeanPct", vm: vm)
            segmentalRow("Left Leg", mass: fieldBinding("leftLegLeanKg", vm: vm), massKey: "leftLegLeanKg", pct: fieldBinding("leftLegLeanPct", vm: vm), pctKey: "leftLegLeanPct", vm: vm)

            // ECW/TBW
            reviewSectionLabel("ECW/TBW")
            reviewRow("Ratio", value: fieldBinding("ecwTbwRatio", vm: vm), unit: "", key: "ecwTbwRatio", vm: vm)

            // Segmental Fat Analysis
            reviewSectionLabel("Segmental Fat Analysis")
            segmentalTableHeader()
            segmentalRow("Right Arm", mass: fieldBinding("rightArmFatKg", vm: vm), massKey: "rightArmFatKg", pct: fieldBinding("rightArmFatPct", vm: vm), pctKey: "rightArmFatPct", vm: vm)
            segmentalRow("Left Arm", mass: fieldBinding("leftArmFatKg", vm: vm), massKey: "leftArmFatKg", pct: fieldBinding("leftArmFatPct", vm: vm), pctKey: "leftArmFatPct", vm: vm)
            segmentalRow("Trunk", mass: fieldBinding("trunkFatKg", vm: vm), massKey: "trunkFatKg", pct: fieldBinding("trunkFatPct", vm: vm), pctKey: "trunkFatPct", vm: vm)
            segmentalRow("Right Leg", mass: fieldBinding("rightLegFatKg", vm: vm), massKey: "rightLegFatKg", pct: fieldBinding("rightLegFatPct", vm: vm), pctKey: "rightLegFatPct", vm: vm)
            segmentalRow("Left Leg", mass: fieldBinding("leftLegFatKg", vm: vm), massKey: "leftLegFatKg", pct: fieldBinding("leftLegFatPct", vm: vm), pctKey: "leftLegFatPct", vm: vm)

            // Additional Metrics
            reviewSectionLabel("Additional Metrics")
            reviewRow("BMR", value: fieldBinding("basalMetabolicRate", vm: vm), unit: "kcal", key: "basalMetabolicRate", vm: vm)
            reviewRow("SMI", value: fieldBinding("skeletalMuscleIndex", vm: vm), unit: "", key: "skeletalMuscleIndex", vm: vm)
            reviewRow("Visceral Fat Level", value: fieldBinding("visceralFatLevel", vm: vm), unit: "", key: "visceralFatLevel", vm: vm)
        }
        .padding(.bottom, 16)
    }

    private func reviewSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(CadreColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    // MARK: - Review Row (three states: normal, low confidence, missing)

    private func reviewRow(
        _ label: String,
        value: Binding<String>,
        unit: String,
        key: String,
        vm: ScanEntryViewModel
    ) -> some View {
        let isLowConfidence = vm.lowConfidenceFields.contains(key)
        let isMissing = value.wrappedValue.isEmpty
        let labelColor = isLowConfidence ? amberColor : CadreColors.textSecondary

        return HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(labelColor)

            Spacer(minLength: 8)

            reviewValueCell(
                value: value,
                unit: unit,
                key: key,
                isLowConfidence: isLowConfidence,
                isMissing: isMissing,
                vm: vm
            )
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func reviewValueCell(
        value: Binding<String>,
        unit: String,
        key: String,
        isLowConfidence: Bool,
        isMissing: Bool,
        vm: ScanEntryViewModel
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if isMissing {
                TextField("--", text: value)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .tracking(-0.2)
                    .foregroundStyle(CadreColors.textTertiary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 50)
                    .onChange(of: value.wrappedValue) { _, _ in
                        vm.markFieldEdited(key)
                    }
            } else {
                TextField("", text: value)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .tracking(-0.2)
                    .foregroundStyle(isLowConfidence ? amberColor : CadreColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 50)
                    .onChange(of: value.wrappedValue) { _, _ in
                        vm.markFieldEdited(key)
                    }
            }

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
                .stroke(
                    isLowConfidence ? amberColor :
                    isMissing ? CadreColors.textTertiary : CadreColors.divider,
                    style: isMissing
                        ? StrokeStyle(lineWidth: 1, dash: [4, 3])
                        : StrokeStyle(lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .frame(minWidth: 92)
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

    private func segmentalRow(
        _ segment: String,
        mass: Binding<String>,
        massKey: String,
        pct: Binding<String>,
        pctKey: String,
        vm: ScanEntryViewModel
    ) -> some View {
        let massLow = vm.lowConfidenceFields.contains(massKey)
        let pctLow = vm.lowConfidenceFields.contains(pctKey)
        let massMissing = mass.wrappedValue.isEmpty
        let pctMissing = pct.wrappedValue.isEmpty
        let labelColor = (massLow || pctLow) ? amberColor : CadreColors.textSecondary

        return HStack(spacing: 6) {
            Text(segment)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            segmentalCell(
                value: mass,
                unit: "lb",
                key: massKey,
                isLowConfidence: massLow,
                isMissing: massMissing,
                vm: vm
            )
            .frame(width: 92)

            segmentalCell(
                value: pct,
                unit: "%",
                key: pctKey,
                isLowConfidence: pctLow,
                isMissing: pctMissing,
                vm: vm
            )
            .frame(width: 78)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 3)
    }

    private func segmentalCell(
        value: Binding<String>,
        unit: String,
        key: String,
        isLowConfidence: Bool,
        isMissing: Bool,
        vm: ScanEntryViewModel
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            TextField(isMissing ? "--" : "", text: value)
                .font(.system(size: 13, weight: .bold, design: .default))
                .tracking(-0.2)
                .foregroundStyle(
                    isMissing ? CadreColors.textTertiary :
                    isLowConfidence ? amberColor : CadreColors.textPrimary
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: value.wrappedValue) { _, _ in
                    vm.markFieldEdited(key)
                }

            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isLowConfidence ? amberColor :
                    isMissing ? CadreColors.textTertiary : CadreColors.divider,
                    style: isMissing
                        ? StrokeStyle(lineWidth: 1, dash: [4, 3])
                        : StrokeStyle(lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - Review Save Button

    private func reviewSaveButton(vm: ScanEntryViewModel) -> some View {
        Button {
            do {
                try vm.save()
                Haptics.success()
                dismiss()
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        } label: {
            Text("Save")
                .font(CadreTypography.buttonLabel)
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(vm.canSave ? CadreColors.accent : CadreColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!vm.canSave)
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Step 5: Manual Entry Form

    private func manualFormStep(vm: ScanEntryViewModel) -> some View {
        VStack(spacing: 0) {
            formHeader(title: "New Scan", vm: vm)

            ScrollView {
                VStack(spacing: 0) {
                    dateChip
                        .padding(.top, 4)
                    scanFormFields(vm: vm)
                }
            }

            // Save button outside scrollable area
            saveButton(vm: vm)
        }
    }

    // MARK: - Shared Form Components

    private func formHeader(title: String, vm: ScanEntryViewModel) -> some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(CadreColors.textSecondary)

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(CadreColors.textPrimary)

            Spacer()

            // Invisible spacer for centering
            Text("Cancel")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.clear)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 6)
    }

    private var dateChip: some View {
        HStack(spacing: 6) {
            Text("Today")
                .font(CadreTypography.dateChip)
                .foregroundStyle(CadreColors.textPrimary)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(CadreColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: CadreRadius.full)
                .stroke(CadreColors.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.full))
        .padding(.top, 16)
    }

    private func confidenceHint(count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
            Text("\(count) low-confidence read\(count == 1 ? "" : "s") \u{2014} please verify")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color(hex: "B89968")) // amber / secondary accent
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 12)
    }

    private func scanFormFields(vm: ScanEntryViewModel) -> some View {
        VStack(spacing: 0) {
            // Core
            formSectionLabel("Core")
            formRow("Weight", value: fieldBinding("weightKg", vm: vm), unit: "kg", key: "weightKg", vm: vm)
            formRow("Body Fat", value: fieldBinding("bodyFatPct", vm: vm), unit: "%", key: "bodyFatPct", vm: vm)
            formRow("Skeletal Muscle", value: fieldBinding("skeletalMuscleMassKg", vm: vm), unit: "kg", key: "skeletalMuscleMassKg", vm: vm)
            formRow("Body Fat Mass", value: fieldBinding("bodyFatMassKg", vm: vm), unit: "kg", key: "bodyFatMassKg", vm: vm)
            formRow("BMI", value: fieldBinding("bmi", vm: vm), unit: "", key: "bmi", vm: vm)
            formRow("BMR", value: fieldBinding("basalMetabolicRate", vm: vm), unit: "kcal", key: "basalMetabolicRate", vm: vm)
            formRow("Total Body Water", value: fieldBinding("totalBodyWaterL", vm: vm), unit: "L", key: "totalBodyWaterL", vm: vm)

            // Body Composition
            formSectionLabel("Body Composition")
            formRow("Intracellular Water", value: fieldBinding("intracellularWaterL", vm: vm), unit: "L", key: "intracellularWaterL", vm: vm)
            formRow("Extracellular Water", value: fieldBinding("extracellularWaterL", vm: vm), unit: "L", key: "extracellularWaterL", vm: vm)
            formRow("Dry Lean Mass", value: fieldBinding("dryLeanMassKg", vm: vm), unit: "kg", key: "dryLeanMassKg", vm: vm)
            formRow("Lean Body Mass", value: fieldBinding("leanBodyMassKg", vm: vm), unit: "kg", key: "leanBodyMassKg", vm: vm)
            formRow("InBody Score", value: fieldBinding("inBodyScore", vm: vm), unit: "", key: "inBodyScore", vm: vm)

            // Segmental Lean
            formSectionLabel("Segmental Lean")
            formRow("Right Arm", value: fieldBinding("rightArmLeanKg", vm: vm), unit: "kg", key: "rightArmLeanKg", vm: vm)
            formRow("Left Arm", value: fieldBinding("leftArmLeanKg", vm: vm), unit: "kg", key: "leftArmLeanKg", vm: vm)
            formRow("Trunk", value: fieldBinding("trunkLeanKg", vm: vm), unit: "kg", key: "trunkLeanKg", vm: vm)
            formRow("Right Leg", value: fieldBinding("rightLegLeanKg", vm: vm), unit: "kg", key: "rightLegLeanKg", vm: vm)
            formRow("Left Leg", value: fieldBinding("leftLegLeanKg", vm: vm), unit: "kg", key: "leftLegLeanKg", vm: vm)

            // Segmental Fat
            formSectionLabel("Segmental Fat")
            formRow("Right Arm", value: fieldBinding("rightArmFatKg", vm: vm), unit: "kg", key: "rightArmFatKg", vm: vm)
            formRow("Left Arm", value: fieldBinding("leftArmFatKg", vm: vm), unit: "kg", key: "leftArmFatKg", vm: vm)
            formRow("Trunk", value: fieldBinding("trunkFatKg", vm: vm), unit: "kg", key: "trunkFatKg", vm: vm)
            formRow("Right Leg", value: fieldBinding("rightLegFatKg", vm: vm), unit: "kg", key: "rightLegFatKg", vm: vm)
            formRow("Left Leg", value: fieldBinding("leftLegFatKg", vm: vm), unit: "kg", key: "leftLegFatKg", vm: vm)
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

    private func formRow(
        _ label: String,
        value: Binding<String>,
        unit: String,
        key: String,
        vm: ScanEntryViewModel
    ) -> some View {
        let isLowConfidence = vm.lowConfidenceFields.contains(key)
        return HStack {
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
            .background(isLowConfidence ? Color(hex: "B89968").opacity(0.08) : CadreColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(
                        isLowConfidence ? Color(hex: "B89968") : CadreColors.divider,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .frame(minWidth: 92)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.vertical, 4)
    }

    private func saveButton(vm: ScanEntryViewModel) -> some View {
        Button {
            do {
                try vm.save()
                Haptics.success()
                dismiss()
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        } label: {
            Text("Save")
                .font(CadreTypography.buttonLabel)
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(vm.canSave ? CadreColors.accent : CadreColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!vm.canSave)
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Push Header

    private func pushHeader(title: String, subtitle: String, backAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(CadreColors.cardElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(CadreColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }

            Spacer()

            // Invisible spacer for centering
            Color.clear
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Continue Button

    private func continueButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(CadreColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

#Preview {
    ScanEntryFlow()
        .modelContainer(for: [Scan.self, Measurement.self], inMemory: true)
        .preferredColorScheme(.dark)
}
