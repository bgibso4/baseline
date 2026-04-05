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
        entries = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Delta = this entry's weight minus the chronologically-previous entry's
    /// weight. Returns nil for the oldest entry (no prior to compare).
    func delta(for entry: WeightEntry) -> Double? {
        // `entries` is reverse-chrono (newest first). The chronologically-prior
        // entry for row `i` is at index `i + 1` in this list.
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return nil }
        let priorIdx = idx + 1
        guard priorIdx < entries.count else { return nil }
        return entry.weight - entries[priorIdx].weight
    }

    func delete(_ entry: WeightEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        refresh()
    }

    func update(_ entry: WeightEntry, weight: Double, notes: String) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.weight = weight
        entry.notes = trimmed.isEmpty ? nil : trimmed
        entry.updatedAt = Date()
        try? modelContext.save()
        refresh()
    }
}
