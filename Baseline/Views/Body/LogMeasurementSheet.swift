import SwiftUI
import SwiftData

/// Sheet for logging a manual tape measurement.
///
/// Visual target: `docs/mockups/body-v4-refinements-2026-04-05.html` (screen 01).
/// Mirrors WeighInSheet pattern but with 56px value number, 56px stepper circles,
/// and a metric picker chip at top.
struct LogMeasurementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let injectedVM: BodyViewModel?
    @State private var bodyVM: BodyViewModel?
    @State private var selectedType: MeasurementType = .waist
    @State private var currentValue: Double = 34.0
    @State private var showTypePicker = false
    @State private var showDatePicker = false
    @State private var selectedDate = Date()

    init(viewModel: BodyViewModel? = nil) {
        self.injectedVM = viewModel
    }

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHandle
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                ScrollView {
                    contentStack
                        .padding(.horizontal, CadreSpacing.sheetHorizontal)
                }

                saveButton
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.bottom, 12)
            }
        }
        .presentationDetents(showDatePicker ? [.large] : [.medium, .large])
        .onAppear {
            if injectedVM == nil, bodyVM == nil {
                bodyVM = BodyViewModel(modelContext: modelContext)
                bodyVM?.refresh()
            } else if bodyVM == nil {
                bodyVM = injectedVM
            }
            // Seed current value from latest measurement of selected type
            loadLatestValue()
        }
        .onChange(of: selectedDate) { _, _ in
            withAnimation { showDatePicker = false }
        }
        .sheet(isPresented: $showTypePicker) {
            typePickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Sections

    private var sheetHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(CadreColors.textTertiary)
            .frame(width: 36, height: 5)
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            dateChip
                .padding(.bottom, 16)

            metricPickerChip
                .padding(.bottom, 22)

            valueDisplay

            stepper
                .padding(.top, 20)
        }
    }

    private var dateChipLabel: String {
        DateFormatting.isToday(selectedDate) ? "Today" : DateFormatting.fullDate(selectedDate)
    }

    private var dateChip: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDatePicker.toggle()
                }
            } label: {
                HStack(spacing: 6) {
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
                .overlay(
                    RoundedRectangle(cornerRadius: CadreRadius.full)
                        .stroke(CadreColors.divider, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: CadreRadius.full))
            }
            .buttonStyle(.plain)

            if showDatePicker {
                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(CadreColors.accent)
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Metric picker chip — tappable, shows current type with chevron.
    /// Mockup: `.meas-picker-chip` with icon + name + chevron.
    private var metricPickerChip: some View {
        Button {
            showTypePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedType.sfSymbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CadreColors.accent)
                    .frame(width: 28, height: 28)
                    .background(CadreColors.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(selectedType.displayName)
                    .font(CadreTypography.measurementPickerName)
                    .foregroundStyle(CadreColors.textPrimary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(CadreColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: CadreRadius.md)
                    .stroke(CadreColors.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
        }
        .buttonStyle(.plain)
    }

    /// 56px hero number with unit suffix (mockup `.value-display .v-num`).
    private var valueDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(String(format: "%.1f", currentValue))
                .font(CadreTypography.measurementHero)
                .tracking(-1.6)
                .foregroundStyle(CadreColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: currentValue)
            Text("in")
                .font(CadreTypography.measurementHeroUnit)
                .foregroundStyle(CadreColors.textSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// Stepper with 56px circles, 80px gap (mockup `.stepper`).
    private var stepper: some View {
        HStack(spacing: 80) {
            Button {
                currentValue = (currentValue - 0.1).rounded(toPlaces: 1)
                Haptics.light()
            } label: {
                stepperCircle(systemName: "minus")
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Decrease \(selectedType.displayName) by 0.1")

            Button {
                currentValue = (currentValue + 0.1).rounded(toPlaces: 1)
                Haptics.light()
            } label: {
                stepperCircle(systemName: "plus")
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Increase \(selectedType.displayName) by 0.1")
        }
    }

    private func stepperCircle(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .light))
            .foregroundStyle(CadreColors.accent)
            .frame(width: 56, height: 56)
            .background(CadreColors.card)
            .overlay(
                Circle()
                    .stroke(CadreColors.accent, lineWidth: 1.5)
            )
            .clipShape(Circle())
    }

    /// 40px margin above save per DESIGN_DECISIONS.md.
    private var saveButton: some View {
        Button {
            // Convert display inches to cm for storage
            let valueCm = currentValue * 2.54
            let resolvedVM = bodyVM ?? injectedVM
            resolvedVM?.saveMeasurement(type: selectedType, valueCm: valueCm, date: selectedDate)
            Haptics.success()
            dismiss()
        } label: {
            Text("Save")
                .font(CadreTypography.buttonLabel)
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(CadreColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: CadreRadius.lg))
        }
        .padding(.top, 40)
    }

    // MARK: - Type Picker

    private var typePickerSheet: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()
                List {
                    ForEach(MeasurementType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                            loadLatestValue()
                            showTypePicker = false
                        } label: {
                            HStack {
                                Image(systemName: type.sfSymbol)
                                    .font(.system(size: 14))
                                    .foregroundStyle(CadreColors.accent)
                                    .frame(width: 24)
                                Text(type.displayName)
                                    .font(CadreTypography.measurementPickerName)
                                    .foregroundStyle(CadreColors.textPrimary)
                                Spacer()
                                if type == selectedType {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(CadreColors.accent)
                                }
                            }
                        }
                        .listRowBackground(CadreColors.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Measurement")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private func loadLatestValue() {
        let resolvedVM = bodyVM ?? injectedVM
        if let latest = resolvedVM?.latestValue(for: selectedType) {
            // Convert stored cm to display inches
            currentValue = (latest.valueCm / 2.54).rounded(toPlaces: 1)
        } else {
            // Default starting values per type (inches)
            currentValue = defaultValue(for: selectedType)
        }
    }

    private func defaultValue(for type: MeasurementType) -> Double {
        switch type {
        case .waist: return 34.0
        case .hips: return 40.0
        case .chest: return 42.0
        case .neck: return 16.0
        case .armLeft, .armRight: return 15.0
        case .thighLeft, .thighRight: return 24.0
        case .calfLeft, .calfRight: return 16.0
        }
    }
}

#Preview {
    LogMeasurementSheet()
        .modelContainer(for: [Scan.self, Measurement.self], inMemory: true)
        .preferredColorScheme(.dark)
}
