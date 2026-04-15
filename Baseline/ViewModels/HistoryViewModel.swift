import Foundation
import SwiftData
import Observation

/// History screen VM — reverse-chronological list of weight entries with
/// delta-from-prior calculation, plus delete / edit support.
@Observable
class HistoryViewModel {
    private let modelContext: ModelContext

    /// Entries sorted newest-first.
    var entries: [WeightEntry] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            entries = try modelContext.fetch(descriptor)
        } catch {
            Log.data.error("Fetch history failed", error)
            entries = []
        }
    }

    /// Delta = this entry's weight minus the chronologically-previous entry's
    /// weight, both converted to the user's preferred display unit.
    /// Returns nil for the oldest entry (no prior to compare).
    func delta(for entry: WeightEntry) -> Double? {
        // `entries` is reverse-chrono (newest first). The chronologically-prior
        // entry for row `i` is at index `i + 1` in this list.
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return nil }
        let priorIdx = idx + 1
        guard priorIdx < entries.count else { return nil }
        let current = UnitConversion.displayWeight(entry.weight, storedUnit: entry.unit)
        let prior = UnitConversion.displayWeight(entries[priorIdx].weight, storedUnit: entries[priorIdx].unit)
        return current - prior
    }

    func delete(_ entry: WeightEntry) {
        modelContext.delete(entry)
        do {
            try modelContext.save()
            Log.data.info("Deleted weight entry")
        } catch {
            Log.data.error("Delete weight entry failed", error)
        }
        refresh()
    }

    func update(_ entry: WeightEntry, weight: Double, notes: String) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.weight = weight
        entry.notes = trimmed.isEmpty ? nil : trimmed
        entry.updatedAt = Date()
        do {
            try modelContext.save()
            Log.data.info("Updated weight entry")
        } catch {
            Log.data.error("Update weight entry failed", error)
        }
        refresh()
    }
}
