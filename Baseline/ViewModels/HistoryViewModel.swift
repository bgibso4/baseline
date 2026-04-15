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

    /// Check if a weight entry exists for the given date (excluding a specific entry).
    func existingEntry(for date: Date, excluding entryID: UUID) -> WeightEntry? {
        let targetDay = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == targetDay }
        )
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.id != entryID })
    }

    func update(_ entry: WeightEntry, weight: Double, notes: String, date: Date? = nil) {
        // Delete any conflicting entry at the target date
        if let date, let conflict = existingEntry(for: date, excluding: entry.id) {
            modelContext.delete(conflict)
            Log.data.info("Deleted conflicting weight entry during overwrite")
        }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.weight = weight
        entry.notes = trimmed.isEmpty ? nil : trimmed
        if let date {
            entry.date = Calendar.current.startOfDay(for: date)
        }
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
