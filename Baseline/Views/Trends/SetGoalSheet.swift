import SwiftUI

/// Sheet for creating or editing a goal from the Trends tab.
///
/// Pass `editingGoal = nil` to create a new goal; pass a non-nil `Goal` to edit it.
struct SetGoalSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goalVM: GoalViewModel
    let defaultMetric: TrendMetric
    let currentValue: Double?
    var editingGoal: Goal? = nil

    @State private var selectedMetric: TrendMetric
    @State private var targetText: String = ""
    @State private var hasDate: Bool = false
    @State private var targetDate: Date
    @State private var showDatePicker = false

    init(
        goalVM: GoalViewModel,
        defaultMetric: TrendMetric,
        currentValue: Double?,
        editingGoal: Goal? = nil
    ) {
        self.goalVM = goalVM
        self.defaultMetric = defaultMetric
        self.currentValue = currentValue
        self.editingGoal = editingGoal

        let oneMonthOut = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        if let goal = editingGoal {
            _selectedMetric = State(initialValue: TrendMetric(rawValue: goal.metric) ?? defaultMetric)
            _targetText = State(initialValue: goal.targetValue.formatted(.number.precision(.fractionLength(0...2))))
            _hasDate = State(initialValue: goal.targetDate != nil)
            _targetDate = State(initialValue: goal.targetDate ?? oneMonthOut)
        } else {
            _selectedMetric = State(initialValue: defaultMetric)
            _targetText = State(initialValue: "")
            _hasDate = State(initialValue: false)
            _targetDate = State(initialValue: oneMonthOut)
        }
    }

    private var isEditing: Bool { editingGoal != nil }
    private var titleText: String { isEditing ? "Edit Goal" : "Set Goal" }
    private var saveButtonText: String { isEditing ? "Update Goal" : "Set Goal" }

    private var canSave: Bool {
        guard let value = Double(targetText), value > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Metric picker
                        formSection {
                            metricPickerRow
                        }

                        // Target value
                        formSection {
                            targetValueRow
                        }

                        // Target date
                        formSection {
                            dateToggleRow
                            if hasDate {
                                divider
                                dateTappableRow
                            }
                        }

                        // Save button
                        saveButton
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                // Date picker overlay — floats on top without affecting layout
                if showDatePicker {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showDatePicker = false }
                        }

                    VStack {
                        DatePicker("", selection: $targetDate, in: Date()..., displayedComponents: .date)
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
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CadreColors.textSecondary)
                }
            }
            .toolbarBackground(CadreColors.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Form sections

    private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(CadreColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metric picker row

    private var metricPickerRow: some View {
        HStack {
            Text("Metric")
                .font(.system(size: 15))
                .foregroundStyle(CadreColors.textPrimary)
            Spacer()
            Menu {
                ForEach(TrendMetric.allCases, id: \.self) { metric in
                    Button {
                        selectedMetric = metric
                    } label: {
                        if metric == selectedMetric {
                            Label(metric.rawValue, systemImage: "checkmark")
                        } else {
                            Text(metric.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedMetric.rawValue)
                        .font(.system(size: 15))
                        .foregroundStyle(CadreColors.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
            .disabled(isEditing)
            .opacity(isEditing ? 0.5 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Target value row

    private var targetValueRow: some View {
        HStack {
            Text("Target")
                .font(.system(size: 15))
                .foregroundStyle(CadreColors.textPrimary)
            Spacer()
            TextField("0", text: $targetText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15))
                .foregroundStyle(CadreColors.textPrimary)
                .frame(maxWidth: 100)
            if !selectedMetric.unit.isEmpty {
                Text(selectedMetric.unit)
                    .font(.system(size: 13))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Date rows

    private var dateToggleRow: some View {
        HStack {
            Text("Target Date")
                .font(.system(size: 15))
                .foregroundStyle(CadreColors.textPrimary)
            Spacer()
            Toggle("", isOn: $hasDate)
                .labelsHidden()
                .tint(CadreColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var dateTappableRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showDatePicker.toggle()
            }
        } label: {
            HStack {
                Text(targetDate, style: .date)
                    .font(.system(size: 15))
                    .foregroundStyle(CadreColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(saveButtonText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSave ? CadreColors.accent : CadreColors.accent.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSave)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(CadreColors.divider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // MARK: - Save logic

    private func save() {
        guard let targetValue = Double(targetText), targetValue > 0 else { return }
        let date = hasDate ? targetDate : nil

        if isEditing {
            goalVM.updateGoal(targetValue: targetValue, targetDate: date)
        } else {
            goalVM.setGoal(
                metric: selectedMetric.rawValue,
                targetValue: targetValue,
                startValue: currentValue ?? 0,
                targetDate: date
            )
        }

        Haptics.success()
        dismiss()
    }
}
