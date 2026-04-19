import SwiftUI
import SwiftData

// MARK: - MetricHistoryView (read-only, for body comp scan-derived metrics)

/// Simple read-only metric history — shows date + value rows.
/// Used for scan-derived body comp metrics (Body Fat, BMI, etc.) from the Body tab.
struct MetricHistoryView: View {
    @AppStorage("lengthUnit") private var lengthUnit = "in"

    let metricName: String
    let unit: String
    let entries: [(date: Date, value: String)]

    private func groupedEntries() -> [(key: String, entries: [(date: Date, value: String)])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var groups: [(key: String, entries: [(date: Date, value: String)])] = []
        var currentKey = ""
        var currentGroup: [(date: Date, value: String)] = []
        for entry in entries {
            let key = formatter.string(from: entry.date)
            if key != currentKey {
                if !currentGroup.isEmpty { groups.append((key: currentKey, entries: currentGroup)) }
                currentKey = key
                currentGroup = [entry]
            } else {
                currentGroup.append(entry)
            }
        }
        if !currentGroup.isEmpty { groups.append((key: currentKey, entries: currentGroup)) }
        return groups
    }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(CadreColors.textTertiary)
                    Text("No history yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            } else {
                List {
                    ForEach(groupedEntries(), id: \.key) { group in
                        Section {
                            ForEach(Array(group.entries.enumerated()), id: \.offset) { _, entry in
                                HStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text({
                                            let f = DateFormatter(); f.dateFormat = "EEEE"
                                            return f.string(from: entry.date)
                                        }())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(CadreColors.textPrimary)
                                        Text({
                                            let f = DateFormatter(); f.dateFormat = "MMM d"
                                            return f.string(from: entry.date)
                                        }())
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(CadreColors.textTertiary)
                                    }

                                    Spacer()

                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(entry.value)
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(CadreColors.textPrimary)
                                        if !unit.isEmpty {
                                            Text(unit.uppercased())
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(CadreColors.textTertiary)
                                        }
                                    }
                                }
                                .listRowBackground(CadreColors.cardGlass)
                                .listRowSeparatorTint(CadreColors.divider.opacity(0.5))
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                            }
                        } header: {
                            Text(group.key.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(CadreColors.textTertiary)
                                .listRowInsets(EdgeInsets(top: 16, leading: 4, bottom: 8, trailing: 0))
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(metricName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MeasurementHistoryView (full edit/delete, for tape measurements)

private typealias BodyMeasurement = Baseline.Measurement

/// Measurement history — reverse-chronological list matching HistoryView's
/// row pattern (date block + value + delta + swipe Edit/Delete).
struct MeasurementHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("lengthUnit") private var lengthUnit = "in"

    let metricType: MeasurementType

    @State private var measurements: [BodyMeasurement] = []
    @State private var editingMeasurement: BodyMeasurement?
    @State private var vm: BodyViewModel?

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            if measurements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(CadreColors.textTertiary)
                    Text("No history yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            } else {
                List {
                    ForEach(groupedMeasurements(), id: \.key) { group in
                        Section {
                            ForEach(group.entries) { measurement in
                                MeasurementRow(
                                    measurement: measurement,
                                    delta: delta(for: measurement)
                                )
                                .listRowBackground(CadreColors.cardGlass)
                                .listRowSeparatorTint(CadreColors.divider.opacity(0.5))
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                                .contentShape(Rectangle())
                                .onTapGesture { editingMeasurement = measurement }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        vm?.deleteMeasurement(measurement)
                                        refresh()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingMeasurement = measurement
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(CadreColors.accent)
                                }
                            }
                        } header: {
                            Text(group.key.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(CadreColors.textTertiary)
                                .listRowInsets(EdgeInsets(top: 16, leading: 4, bottom: 8, trailing: 0))
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(metricType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingMeasurement) { measurement in
            EditMeasurementSheet(
                measurement: measurement,
                onSave: { newValue, notes, date in
                    let valueCm = lengthUnit == "cm" ? newValue : UnitConversion.inToCm(newValue)
                    vm?.editMeasurement(
                        measurement,
                        newValueCm: valueCm,
                        notes: notes,
                        date: date
                    )
                    refresh()
                },
                onDelete: {
                    vm?.deleteMeasurement(measurement)
                    refresh()
                },
                checkConflict: { date, measurementID in
                    let targetDay = Calendar.current.startOfDay(for: date)
                    let typeRaw = metricType.rawValue
                    let descriptor = FetchDescriptor<BodyMeasurement>(
                        predicate: #Predicate { $0.date == targetDay && $0.type == typeRaw }
                    )
                    let existing = (try? modelContext.fetch(descriptor)) ?? []
                    return existing.contains(where: { $0.id != measurementID })
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            if vm == nil {
                vm = BodyViewModel(modelContext: modelContext)
            }
            refresh()
        }
    }

    private func refresh() {
        measurements = vm?.allMeasurements(ofType: metricType) ?? []
    }

    private func groupedMeasurements() -> [(key: String, entries: [BodyMeasurement])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var groups: [(key: String, entries: [BodyMeasurement])] = []
        var currentKey = ""
        var currentGroup: [BodyMeasurement] = []
        for m in measurements {
            let key = formatter.string(from: m.date)
            if key != currentKey {
                if !currentGroup.isEmpty { groups.append((key: currentKey, entries: currentGroup)) }
                currentKey = key
                currentGroup = [m]
            } else {
                currentGroup.append(m)
            }
        }
        if !currentGroup.isEmpty { groups.append((key: currentKey, entries: currentGroup)) }
        return groups
    }

    /// Delta from the chronologically-previous entry, in display units.
    private func delta(for measurement: BodyMeasurement) -> Double? {
        guard let idx = measurements.firstIndex(where: { $0.id == measurement.id }) else { return nil }
        let priorIdx = idx + 1
        guard priorIdx < measurements.count else { return nil }
        let current = UnitConversion.displayLength(measurement.valueCm).value
        let prior = UnitConversion.displayLength(measurements[priorIdx].valueCm).value
        return current - prior
    }
}

// MARK: - Row

private struct MeasurementRow: View {
    let measurement: BodyMeasurement
    let delta: Double?

    @AppStorage("lengthUnit") private var lengthUnit = "in"

    private var displayUnit: String { lengthUnit }

    private var displayValue: Double {
        UnitConversion.displayLength(measurement.valueCm).value
    }

    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: measurement.date)
    }

    private var weekdayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: measurement.date)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(weekdayLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(dateLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", displayValue))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(displayUnit.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                }

                if let delta {
                    Text(formatDelta(delta))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(deltaColor(delta))
                        .padding(.leading, 10)
                }
            }

            if let notes = measurement.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(CadreColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
        }
    }

    private func formatDelta(_ d: Double) -> String {
        let rounded = (d * 10).rounded() / 10
        if abs(rounded) < 0.05 { return "0.0" }
        let sign = rounded > 0 ? "+" : "\u{2212}"
        return "\(sign)\(String(format: "%.1f", abs(rounded)))"
    }

    private func deltaColor(_ d: Double) -> Color {
        let rounded = (d * 10).rounded() / 10
        if abs(rounded) < 0.05 { return CadreColors.neutral }
        // For measurements: increase = positive (green), decrease = negative (red)
        // Opposite of weight — bigger arms/chest is generally a gain
        return rounded > 0 ? CadreColors.positive : CadreColors.negative
    }
}

// MARK: - Edit Sheet

private struct EditMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let measurement: BodyMeasurement
    let onSave: (Double, String, Date) -> Void
    let onDelete: () -> Void
    let checkConflict: (Date, UUID) -> Bool

    @AppStorage("lengthUnit") private var lengthUnit = "in"
    @State private var valueText: String
    @State private var notes: String
    @State private var selectedDate: Date
    @State private var showDatePicker = false
    @State private var showOverwriteAlert = false
    @FocusState private var isFieldFocused: Bool

    init(
        measurement: BodyMeasurement,
        onSave: @escaping (Double, String, Date) -> Void,
        onDelete: @escaping () -> Void,
        checkConflict: @escaping (Date, UUID) -> Bool
    ) {
        self.measurement = measurement
        self.onSave = onSave
        self.onDelete = onDelete
        self.checkConflict = checkConflict
        let display = UnitConversion.displayLength(measurement.valueCm)
        self._valueText = State(initialValue: String(format: "%.1f", display.value))
        self._notes = State(initialValue: measurement.notes ?? "")
        self._selectedDate = State(initialValue: measurement.date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section {
                        HStack {
                            Text("Value")
                                .foregroundStyle(CadreColors.textSecondary)
                            Spacer()
                            TextField("Value", text: $valueText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(CadreColors.textPrimary)
                                .focused($isFieldFocused)
                            Text(lengthUnit)
                                .foregroundStyle(CadreColors.textTertiary)
                        }
                        Button {
                            isFieldFocused = false
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showDatePicker.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Date")
                                    .foregroundStyle(CadreColors.textSecondary)
                                Spacer()
                                Text(DateFormatting.fullDate(selectedDate))
                                    .foregroundStyle(CadreColors.textPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(CadreColors.textTertiary)
                            }
                        }
                    }
                    .listRowBackground(CadreColors.card)

                    Section("Notes") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .foregroundStyle(CadreColors.textPrimary)
                            .focused($isFieldFocused)
                    }
                    .listRowBackground(CadreColors.card)

                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Measurement")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(CadreColors.card)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .background(CadreColors.bg)

                if showDatePicker {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showDatePicker = false }
                        }

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
            .navigationTitle("Edit Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedDate) { _, _ in
                withAnimation { showDatePicker = false }
            }
            .alert("Overwrite Measurement?", isPresented: $showOverwriteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Overwrite", role: .destructive) { performSave() }
            } message: {
                Text("You already have a measurement for this date. Do you want to replace it?")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CadreColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let dateChanged = Calendar.current.startOfDay(for: selectedDate) != measurement.date
                        if dateChanged && checkConflict(selectedDate, measurement.id) {
                            showOverwriteAlert = true
                        } else {
                            performSave()
                        }
                    }
                    .foregroundStyle(CadreColors.accent)
                }
            }
        }
    }

    private func performSave() {
        if let v = Double(valueText) {
            onSave(v, notes, selectedDate)
        }
        dismiss()
    }
}
