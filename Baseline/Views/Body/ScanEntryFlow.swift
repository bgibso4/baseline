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
                    switch vm.currentStep {
                    case .selectType:
                        scanTypeStep(vm: vm)
                    case .selectMethod:
                        inputMethodStep(vm: vm)
                    case .camera:
                        cameraStep(vm: vm)
                    case .review:
                        reviewFormStep(vm: vm)
                    case .manualEntry:
                        manualFormStep(vm: vm)
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
            ScanCameraView(
                onCapture: { image in
                    Task {
                        await vm.processImage(image)
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

    private func reviewFormStep(vm: ScanEntryViewModel) -> some View {
        VStack(spacing: 0) {
            formHeader(title: "Review Scan", vm: vm)

            ScrollView {
                VStack(spacing: 0) {
                    dateChip

                    // Confidence hint
                    if !vm.lowConfidenceFields.isEmpty {
                        confidenceHint(count: vm.lowConfidenceFields.count)
                    }

                    scanFormFields(vm: vm)
                }
            }

            // Save button outside scrollable area
            saveButton(vm: vm)
        }
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
        @Bindable var bvm = vm
        return VStack(spacing: 0) {
            // Core
            formSectionLabel("Core")
            formRow("Weight", value: $bvm.weightKg, unit: "kg", key: "weightKg", vm: vm)
            formRow("Body Fat", value: $bvm.bodyFatPct, unit: "%", key: "bodyFatPct", vm: vm)
            formRow("Skeletal Muscle", value: $bvm.skeletalMuscleMassKg, unit: "kg", key: "skeletalMuscleMassKg", vm: vm)
            formRow("Body Fat Mass", value: $bvm.bodyFatMassKg, unit: "kg", key: "bodyFatMassKg", vm: vm)
            formRow("BMI", value: $bvm.bmi, unit: "", key: "bmi", vm: vm)
            formRow("BMR", value: $bvm.basalMetabolicRate, unit: "kcal", key: "basalMetabolicRate", vm: vm)
            formRow("Total Body Water", value: $bvm.totalBodyWaterL, unit: "L", key: "totalBodyWaterL", vm: vm)

            // Body Composition
            formSectionLabel("Body Composition")
            formRow("Intracellular Water", value: $bvm.intracellularWaterL, unit: "L", key: "intracellularWaterL", vm: vm)
            formRow("Extracellular Water", value: $bvm.extracellularWaterL, unit: "L", key: "extracellularWaterL", vm: vm)
            formRow("Dry Lean Mass", value: $bvm.dryLeanMassKg, unit: "kg", key: "dryLeanMassKg", vm: vm)
            formRow("Lean Body Mass", value: $bvm.leanBodyMassKg, unit: "kg", key: "leanBodyMassKg", vm: vm)
            formRow("InBody Score", value: $bvm.inBodyScore, unit: "", key: "inBodyScore", vm: vm)

            // Segmental Lean
            formSectionLabel("Segmental Lean")
            formRow("Right Arm", value: $bvm.rightArmLeanKg, unit: "kg", key: "rightArmLeanKg", vm: vm)
            formRow("Left Arm", value: $bvm.leftArmLeanKg, unit: "kg", key: "leftArmLeanKg", vm: vm)
            formRow("Trunk", value: $bvm.trunkLeanKg, unit: "kg", key: "trunkLeanKg", vm: vm)
            formRow("Right Leg", value: $bvm.rightLegLeanKg, unit: "kg", key: "rightLegLeanKg", vm: vm)
            formRow("Left Leg", value: $bvm.leftLegLeanKg, unit: "kg", key: "leftLegLeanKg", vm: vm)

            // Segmental Fat
            formSectionLabel("Segmental Fat")
            formRow("Right Arm", value: $bvm.rightArmFatKg, unit: "kg", key: "rightArmFatKg", vm: vm)
            formRow("Left Arm", value: $bvm.leftArmFatKg, unit: "kg", key: "leftArmFatKg", vm: vm)
            formRow("Trunk", value: $bvm.trunkFatKg, unit: "kg", key: "trunkFatKg", vm: vm)
            formRow("Right Leg", value: $bvm.rightLegFatKg, unit: "kg", key: "rightLegFatKg", vm: vm)
            formRow("Left Leg", value: $bvm.leftLegFatKg, unit: "kg", key: "leftLegFatKg", vm: vm)
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
