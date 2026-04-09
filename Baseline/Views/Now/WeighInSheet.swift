import SwiftUI
import SwiftData
import PhotosUI

/// Sheet presented from Now screen for logging today's weight.
///
/// Visual target: `docs/mockups/weighin-APPROVED-2026-04-04.html`.
/// Layout: drag handle → date pill → big weight number + delta preview →
/// ±0.1 stepper → optional notes/photo chips → Save button.
struct WeighInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Track unit preference so SwiftUI re-renders when it changes
    @AppStorage("weightUnit") private var weightUnit = "lb"

    let lastWeight: Double?
    let unit: String
    private let injectedVM: WeighInViewModel?
    private let onSave: (() -> Void)?

    @State private var vm: WeighInViewModel?
    @State private var showNoteField: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showOverwriteAlert = false
    @FocusState private var isFieldFocused: Bool

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
        NavigationStack {
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

            // Date picker overlay — floats on top without affecting layout
            if showDatePicker {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showDatePicker = false }
                    }

                VStack {
                    DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isFieldFocused = false }
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .navigationBarHidden(true)
        } // NavigationStack
        .presentationDetents(sheetDetents)
        .onAppear {
            guard injectedVM == nil, vm == nil else { return }
            vm = WeighInViewModel(
                modelContext: modelContext,
                lastWeight: lastWeight,
                unit: unit
            )
        }
        .onChange(of: selectedDate) { _, _ in
            withAnimation { showDatePicker = false }
        }
    }

    /// Adaptive sheet detents based on content state.
    private var sheetDetents: Set<PresentationDetent> {
        if photoData != nil {
            return [.large]
        }
        return [.medium]
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var dateChipLabel: String {
        DateFormatting.isToday(selectedDate) ? "Today" : DateFormatting.fullDate(selectedDate)
    }

    private var dateChip: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showDatePicker.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(dateChipLabel)
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
        _ = weightUnit  // SwiftUI dependency: re-render when unit preference changes
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
                Haptics.light()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(CadreColors.accent)
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Decrease weight by 0.1")

            Button {
                vm?.increment()
                Haptics.light()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(CadreColors.accent)
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Increase weight by 0.1")
        }
    }

    private var addChipsRow: some View {
        HStack(spacing: 10) {
            chip(
                label: showNoteField ? "Note" : "Add note",
                systemImage: "square.and.pencil",
                filled: showNoteField
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showNoteField.toggle()
                }
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                chip(label: photoData != nil ? "Photo" : "Add photo", systemImage: "camera", filled: photoData != nil)
            }
            .buttonStyle(.plain)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            photoData = data
                        }
                    }
                }
            }
        }
    }

    private func chip(label: String, systemImage: String, filled: Bool) -> some View {
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

    private func chip(label: String, systemImage: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chip(label: label, systemImage: systemImage, filled: filled)
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
        .focused($isFieldFocused)
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

    // Photo stub removed — replaced with PhotosPicker in addChipsRow

    private var saveButton: some View {
        // 40px margin above Save button per DESIGN_DECISIONS.md
        Button {
            if vm?.existingEntry(for: selectedDate) != nil {
                showOverwriteAlert = true
            } else {
                performSave()
            }
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
        .alert("Overwrite Entry?", isPresented: $showOverwriteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Overwrite", role: .destructive) {
                performSave()
            }
        } message: {
            Text("You already have a weigh-in for this date. Do you want to replace it?")
        }
    }

    private func performSave() {
        vm?.save(date: selectedDate, photoData: photoData)
        Haptics.success()
        onSave?()
        dismiss()
    }
}

#Preview {
    WeighInSheet(lastWeight: 197.4, unit: "lb")
        .modelContainer(for: [WeightEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
