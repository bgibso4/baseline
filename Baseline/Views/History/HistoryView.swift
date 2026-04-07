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
            CadreColors.bg.ignoresSafeArea()

            if let vm, !vm.entries.isEmpty {
                list(vm: vm)
            } else {
                emptyState
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CadreColors.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(
                entry: entry,
                onSave: { weight, notes in
                    vm?.update(entry, weight: weight, notes: notes)
                },
                onDelete: {
                    vm?.delete(entry)
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

    // MARK: - List

    private func list(vm: HistoryViewModel) -> some View {
        List {
            ForEach(vm.entries) { entry in
                HistoryRow(
                    entry: entry,
                    delta: vm.delta(for: entry)
                )
                .listRowBackground(CadreColors.bg)
                .listRowSeparatorTint(CadreColors.divider)
                .listRowInsets(EdgeInsets(top: 12, leading: CadreSpacing.md, bottom: 12, trailing: CadreSpacing.md))
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
        }
        .listStyle(.plain)
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

    private var dayNumber: String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: entry.date))"
    }

    private var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: entry.date)
    }

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Date block — mirrors ScanHistoryView pattern
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayNumber)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(monthYear)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
                .frame(width: 60, alignment: .leading)

                Spacer()

                // Weight + delta — always in user's preferred unit
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(UnitConversion.formatWeight(displayWeight, unit: displayUnit))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(CadreColors.textPrimary)
                        Text(displayUnit)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                    if let delta {
                        Text(UnitConversion.formatDelta(delta))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(deltaColor(delta))
                    }
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
        var label = "\(weekday), \(monthYear) \(dayNumber), \(UnitConversion.formatWeight(displayWeight, unit: displayUnit)) \(displayUnit)"
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
    let onSave: (Double, String) -> Void
    let onDelete: () -> Void

    private let displayUnit: String
    @State private var weightText: String
    @State private var notes: String

    init(
        entry: WeightEntry,
        onSave: @escaping (Double, String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        let pref = UnitConversion.preferredWeightUnit
        self.displayUnit = pref
        let displayW = UnitConversion.displayWeight(entry.weight, storedUnit: entry.unit)
        self._weightText = State(initialValue: String(format: "%.1f", displayW))
        self._notes = State(initialValue: entry.notes ?? "")
    }

    var body: some View {
        NavigationStack {
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
                        Text(displayUnit)
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                    HStack {
                        Text("Date")
                            .foregroundStyle(CadreColors.textSecondary)
                        Spacer()
                        Text(DateFormatting.fullDate(entry.date))
                            .foregroundStyle(CadreColors.textPrimary)
                    }
                }
                .listRowBackground(CadreColors.card)

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .foregroundStyle(CadreColors.textPrimary)
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
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CadreColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let w = Double(weightText) {
                            // Convert from display unit back to the entry's stored unit
                            let storedW: Double
                            if displayUnit == entry.unit {
                                storedW = w
                            } else if displayUnit == "lb" {
                                storedW = UnitConversion.lbToKg(w)
                            } else {
                                storedW = UnitConversion.kgToLb(w)
                            }
                            onSave(storedW, notes)
                        }
                        dismiss()
                    }
                    .foregroundStyle(CadreColors.accent)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
    }
    .preferredColorScheme(.dark)
}
