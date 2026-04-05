import SwiftUI
import SwiftData

/// Sheet presented from Now screen for logging today's weight.
///
/// Visual target: `docs/mockups/weighin-APPROVED-2026-04-04.html`.
/// Layout: drag handle → date pill → big weight number + delta preview →
/// ±0.1 stepper → optional notes/photo chips → Save button.
struct WeighInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let lastWeight: Double?
    let unit: String
    private let injectedVM: WeighInViewModel?
    private let onSave: (() -> Void)?

    @State private var vm: WeighInViewModel?
    @State private var showNoteField: Bool = false
    @State private var showPhotoStub: Bool = false

    init(
        lastWeight: Double?,
        unit: String,
        viewModel: WeighInViewModel? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.lastWeight = lastWeight
        self.unit = unit
        self.injectedVM = viewModel
        self.onSave = onSave
        self._vm = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHandle
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                contentStack
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)

                Spacer(minLength: 0)

                saveButton
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            guard injectedVM == nil, vm == nil else { return }
            vm = WeighInViewModel(
                modelContext: modelContext,
                lastWeight: lastWeight,
                unit: unit
            )
        }
    }

    // MARK: - Sections

    private var sheetHandle: some View {
        // 36×5 drag bar, tertiary text color (mockup .sheet-handle)
        RoundedRectangle(cornerRadius: 3)
            .fill(CadreColors.textTertiary)
            .frame(width: 36, height: 5)
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            dateChip
                .padding(.bottom, 20)

            weightDisplay

            deltaPreview
                .padding(.top, 10)

            stepper
                .padding(.top, 24)

            addChipsRow
                .padding(.top, 20)

            if showNoteField {
                noteFieldView
                    .padding(.top, 16)
            }

            if showPhotoStub {
                photoStubView
                    .padding(.top, 16)
            }
        }
    }

    private var dateChip: some View {
        Button {
            // TODO: date picker — design calls for graphical DatePicker, out of scope for Task 10
        } label: {
            HStack(spacing: 8) {
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
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var weightDisplay: some View {
        // 92pt bold, -3px tracking hero (mockup .weight-num)
        let currentWeight = vm?.currentWeight ?? (lastWeight ?? 0)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(UnitConversion.formatWeight(currentWeight, unit: unit))
                .font(CadreTypography.weighInHero)
                .tracking(-3)
                .foregroundStyle(CadreColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: currentWeight)
            Text(unit)
                .font(CadreTypography.weighInHeroUnit)
                .foregroundStyle(CadreColors.textSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var deltaPreview: some View {
        // Small muted caption under hero (mockup .delta-preview)
        Text(deltaText)
            .font(CadreTypography.deltaPreview)
            .foregroundStyle(CadreColors.textTertiary)
    }

    private var deltaText: String {
        let current = vm?.currentWeight ?? lastWeight ?? 0
        guard let last = lastWeight else { return "First entry" }
        let delta = (current - last).rounded(toPlaces: 1)
        if abs(delta) < 0.05 {
            return "Same as yesterday"
        }
        let sign = delta > 0 ? "+" : "−"
        let magnitude = String(format: "%.1f", abs(delta))
        return "\(sign)\(magnitude) from yesterday"
    }

    private var stepper: some View {
        // Two 64px accent circles, 100px apart (mockup .stepper / .step-btn)
        HStack(spacing: 100) {
            Button {
                vm?.decrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(CadreColors.accent)
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)

            Button {
                vm?.increment()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(CadreColors.accent)
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
        }
    }

    private var addChipsRow: some View {
        HStack(spacing: 10) {
            chip(
                label: showNoteField ? "Note" : "Add note",
                systemImage: "square.and.pencil",
                filled: showNoteField
            ) {
                showNoteField.toggle()
            }
            chip(
                label: showPhotoStub ? "Photo" : "Add photo",
                systemImage: "camera",
                filled: showPhotoStub
            ) {
                // TODO: wire PhotosPicker + storage
                showPhotoStub.toggle()
            }
        }
    }

    private func chip(label: String, systemImage: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(filled ? CadreColors.accent : CadreColors.textSecondary)
                Text(label)
                    .font(CadreTypography.addChip)
                    .foregroundStyle(filled ? CadreColors.textPrimary : CadreColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(filled ? CadreColors.cardElevated : CadreColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var noteFieldView: some View {
        // Inline text field (mockup .note-field)
        TextField(
            "",
            text: Binding(
                get: { vm?.notes ?? "" },
                set: { vm?.notes = $0 }
            ),
            prompt: Text("Add a note…").foregroundColor(CadreColors.textTertiary),
            axis: .vertical
        )
        .font(CadreTypography.noteField)
        .foregroundStyle(CadreColors.textPrimary)
        .lineLimit(2...4)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .background(CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CadreColors.cardElevated, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var photoStubView: some View {
        // TODO: wire PhotosPicker + storage — visual stub only
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [CadreColors.accent, CadreColors.accent.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "camera")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(CadreColors.textPrimary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Tap to add photo")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CadreColors.textPrimary)
                Text("Photos picker not yet wired")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            Spacer(minLength: 0)
            Button {
                showPhotoStub = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 80)
        .background(
            LinearGradient(
                colors: [CadreColors.divider, CadreColors.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var saveButton: some View {
        // 40px margin above Save button per DESIGN_DECISIONS.md
        Button {
            vm?.save()
            onSave?()
            dismiss()
        } label: {
            Text("Save")
                .font(CadreTypography.buttonLabel)
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(CadreColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.top, 40)
    }
}

#Preview {
    WeighInSheet(lastWeight: 197.4, unit: "lb")
        .modelContainer(for: [WeightEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
