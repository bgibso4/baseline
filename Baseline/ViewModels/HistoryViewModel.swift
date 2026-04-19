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
        let entryID = entry.id
        modelContext.delete(entry)
        do {
            try modelContext.save()
            Log.data.info("Deleted weight entry")
        } catch {
            Log.data.error("Delete weight entry failed", error)
        }
        Task { await HealthKitManager.mirror.deleteSamples(forSourceID: entryID) }
        refresh()
    }

    /// Check if a weight entry exists for the given date (excluding a specific entry).
    func existingEntry(for date: Date, excluding entryID: UUID) -> WeightEntry? {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }
        )
        return (try? modelContext.fetch(descriptor))?.first(where: { $0.id != entryID })
    }

    func update(_ entry: WeightEntry, weight: Double, notes: String, date: Date? = nil) {
        // Delete any conflicting entry at the target date — capture its id
        // first so we can remove its HK samples after the SwiftData save.
        var conflictID: UUID?
        if let date, let conflict = existingEntry(for: date, excluding: entry.id) {
            conflictID = conflict.id
            modelContext.delete(conflict)
            Log.data.info("Deleted conflicting weight entry during overwrite")
        }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.weight = weight
        entry.notes = trimmed.isEmpty ? nil : trimmed
        if let date {
            // Preserve time of day: use noon on the selected date so it sorts correctly
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            let originalTime = Calendar.current.dateComponents([.hour, .minute, .second], from: entry.date)
            components.hour = originalTime.hour
            components.minute = originalTime.minute
            components.second = originalTime.second
            entry.date = Calendar.current.date(from: components) ?? date
        }
        entry.updatedAt = Date()
        do {
            try modelContext.save()
            Log.data.info("Updated weight entry")
        } catch {
            Log.data.error("Update weight entry failed", error)
        }
        // Wipe stale HK samples (self + any overwritten conflict) then write
        // fresh samples for this entry at its new date/value. Extract
        // primitives before the Task so no SwiftData managed object crosses
        // actor boundaries.
        let entryID = entry.id
        let entryWeight = entry.weight
        let entryUnit = entry.unit
        let entryDate = entry.date
        Task {
            if let conflictID { await HealthKitManager.mirror.deleteSamples(forSourceID: conflictID) }
            await HealthKitManager.mirror.deleteSamples(forSourceID: entryID)
            await HealthKitManager.mirror.saveWeight(
                weight: entryWeight,
                unit: entryUnit,
                date: entryDate,
                sourceID: entryID
            )
        }
        refresh()
    }
}
