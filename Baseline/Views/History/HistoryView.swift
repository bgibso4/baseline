import SwiftUI
import SwiftData

/// History screen — reverse-chronological list of weight entries.
///
/// Row layout (per DESIGN_DECISIONS.md):
///   `Wed, Apr 3   197.4 lb   +0.2`
///   date (day + weekday) on the left, delta + value on the right.
///
/// Interactions:
///   - Swipe → Edit / Delete
///   - Tap row → Edit sheet
///   - Empty state: "No entries yet" centered, muted
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: HistoryViewModel?
    @State private var editingEntry: WeightEntry?

    private let injectedVM: HistoryViewModel?

    init(viewModel: HistoryViewModel? = nil) {
        self.injectedVM = viewModel
        self._vm = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            if let vm, !vm.entries.isEmpty {
                list(vm: vm)
            } else {
                emptyState
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(
                entry: entry,
                onSave: { weight, notes, date in
                    vm?.update(entry, weight: weight, notes: notes, date: date)
                },
                onDelete: {
                    vm?.delete(entry)
                },
                checkConflict: { date, entryID in
                    vm?.existingEntry(for: date, excluding: entryID) != nil
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            guard injectedVM == nil else { return }
            if vm == nil {
                vm = HistoryViewModel(modelContext: modelContext)
            }
            vm?.refresh()
        }
    }

    // MARK: - Grouped by month

    /// Groups entries by "Month Year" (e.g. "April 2026"), preserving reverse-chronological order.
    private func groupedEntries(_ entries: [WeightEntry]) -> [(key: String, entries: [WeightEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var groups: [(key: String, entries: [WeightEntry])] = []
        var currentKey = ""
        var currentGroup: [WeightEntry] = []
        for entry in entries {
            let key = formatter.string(from: entry.date)
            if key != currentKey {
                if !currentGroup.isEmpty {
                    groups.append((key: currentKey, entries: currentGroup))
                }
                currentKey = key
                currentGroup = [entry]
            } else {
                currentGroup.append(entry)
            }
        }
        if !currentGroup.isEmpty {
            groups.append((key: currentKey, entries: currentGroup))
        }
        return groups
    }

    // MARK: - List

    private func list(vm: HistoryViewModel) -> some View {
        List {
            ForEach(groupedEntries(vm.entries), id: \.key) { group in
                Section {
                    ForEach(group.entries) { entry in
                        HistoryRow(
                            entry: entry,
                            delta: vm.delta(for: entry)
                        )
                        .listRowBackground(CadreColors.cardGlass)
                        .listRowSeparatorTint(CadreColors.divider.opacity(0.5))
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .contentShape(Rectangle())
                        .onTapGesture { editingEntry = entry }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                vm.delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingEntry = entry
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

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No entries yet")
                .font(CadreTypography.historyEmpty)
                .foregroundStyle(CadreColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let entry: WeightEntry
    let delta: Double?

    // Track unit preference so SwiftUI re-renders when it changes
    @AppStorage("weightUnit") private var weightUnit = "lb"

    private var displayUnit: String { UnitConversion.preferredWeightUnit }

    private var displayWeight: Double {
        _ = weightUnit  // SwiftUI dependency: re-render when unit preference changes
        return UnitConversion.displayWeight(entry.weight, storedUnit: entry.unit)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: entry.date)
    }

    /// Show time only if the entry was logged on the day it represents.
    /// Back-dated entries have meaningless times (midnight or log time).
    private var showTime: Bool {
        Calendar.current.isDate(entry.date, inSameDayAs: entry.createdAt)
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: entry.date)
    }

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: entry.date)
    }

    private var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Date + optional time on the left
                VStack(alignment: .leading, spacing: 3) {
                    Text(dateLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                    if showTime {
                        Text(timeLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                }

                Spacer()

                // Weight — big and bold on the right
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(UnitConversion.formatWeight(displayWeight, unit: displayUnit))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(displayUnit.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                }

                // Delta badge
                if let delta {
                    Text(UnitConversion.formatDelta(delta))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(deltaColor(delta))
                        .padding(.leading, 10)
                }
            }

            // Notes caption below (if present)
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(CadreColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        var label = "\(weekday), \(dateLabel), \(UnitConversion.formatWeight(displayWeight, unit: displayUnit)) \(displayUnit)"
        if let delta {
            label += ", \(deltaText(delta)) change"
        }
        return label
    }

    private func deltaText(_ d: Double) -> String {
        let rounded = (d * 10).rounded() / 10
        if abs(rounded) < 0.05 { return "0.0" }
        let sign = rounded > 0 ? "+" : "\u{2212}"
        return "\(sign)\(String(format: "%.1f", abs(rounded)))"
    }

    private func deltaColor(_ d: Double) -> Color {
        let rounded = (d * 10).rounded() / 10
        if abs(rounded) < 0.05 { return CadreColors.neutral }
        // Weight gain = negative (red), loss = positive (green).
        return rounded < 0 ? CadreColors.positive : CadreColors.negative
    }
}

// MARK: - Edit Sheet

private struct EditEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: WeightEntry
    let onSave: (Double, String, Date) -> Void
    let onDelete: () -> Void
    let checkConflict: (Date, UUID) -> Bool

    private let displayUnit: String
    @State private var weightText: String
    @State private var notes: String
    @State private var selectedDate: Date
    @State private var showDatePicker = false
    @State private var showOverwriteAlert = false

    init(
        entry: WeightEntry,
        onSave: @escaping (Double, String, Date) -> Void,
        onDelete: @escaping () -> Void,
        checkConflict: @escaping (Date, UUID) -> Bool
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        self.checkConflict = checkConflict
        let pref = UnitConversion.preferredWeightUnit
        self.displayUnit = pref
        let displayW = UnitConversion.displayWeight(entry.weight, storedUnit: entry.unit)
        self._weightText = State(initialValue: String(format: "%.1f", displayW))
        self._notes = State(initialValue: entry.notes ?? "")
        self._selectedDate = State(initialValue: entry.date)
    }

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section {
                        HStack {
                            Text("Weight")
                                .foregroundStyle(CadreColors.textSecondary)
                            Spacer()
                            TextField("Weight", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(CadreColors.textPrimary)
                                .focused($isFieldFocused)
                            Text(displayUnit)
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
                            Text("Delete Entry")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(CadreColors.card)
                }
                .scrollContentBackground(.hidden)
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
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedDate) { _, _ in
                withAnimation { showDatePicker = false }
            }
            .alert("Overwrite Entry?", isPresented: $showOverwriteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Overwrite", role: .destructive) { performSave() }
            } message: {
                Text("You already have a weigh-in for this date. Do you want to replace it?")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CadreColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let dateChanged = !Calendar.current.isDate(selectedDate, inSameDayAs: entry.date)
                        if dateChanged && checkConflict(selectedDate, entry.id) {
                            showOverwriteAlert = true
                        } else {
                            performSave()
                        }
                    }
                    .foregroundStyle(CadreColors.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFieldFocused = false }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    private func performSave() {
        if let w = Double(weightText) {
            let storedW: Double
            if displayUnit == entry.unit {
                storedW = w
            } else if displayUnit == "lb" {
                storedW = UnitConversion.lbToKg(w)
            } else {
                storedW = UnitConversion.kgToLb(w)
            }
            onSave(storedW, notes, selectedDate)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
    }
    .preferredColorScheme(.dark)
}
