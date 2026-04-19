import Foundation
import SwiftData
import Observation

@Observable
class WeighInViewModel {
    private let modelContext: ModelContext
    let unit: String

    var currentWeight: Double
    var notes: String = ""

    init(modelContext: ModelContext, lastWeight: Double?, unit: String) {
        self.modelContext = modelContext
        self.unit = unit
        self.currentWeight = lastWeight ?? (unit == "kg" ? 70.0 : 150.0)
    }

    /// Check if a weigh-in already exists for the given date (any time that day).
    func existingEntry(for date: Date) -> WeightEntry? {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func increment() {
        currentWeight = (currentWeight + 0.1).rounded(toPlaces: 1)
    }

    func decrement() {
        currentWeight = (currentWeight - 0.1).rounded(toPlaces: 1)
    }

    func save(date: Date = Date(), photoData: Data? = nil) {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }
        )
        descriptor.fetchLimit = 1

        let savedEntry: WeightEntry
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.weight = currentWeight
            existing.notes = notesToSave
            if let photo = photoData { existing.photoData = photo }
            existing.updatedAt = Date()
            savedEntry = existing
        } else {
            let entry = WeightEntry(weight: currentWeight, unit: unit, date: date, notes: notesToSave, photoData: photoData)
            modelContext.insert(entry)
            savedEntry = entry
        }

        do {
            try modelContext.save()
            Log.data.info("Saved weight entry: \(currentWeight) \(unit)")
        } catch {
            Log.data.error("Save weight entry failed", error)
        }
        SyncHelper.mirrorRecord(savedEntry)

        // Clear any prior HK samples for this entry before writing the fresh
        // value — idempotent on first save (no prior samples exist), and on
        // same-day overwrite removes the stale sample tied to this entry.id.
        // Extract primitives up front so the Task doesn't capture a SwiftData
        // managed object across actor boundaries.
        let entryID = savedEntry.id
        let entryWeight = savedEntry.weight
        let entryUnit = savedEntry.unit
        let entryDate = savedEntry.date
        Task {
            await HealthKitManager.mirror.deleteSamples(forSourceID: entryID)
            await HealthKitManager.mirror.saveWeight(
                weight: entryWeight,
                unit: entryUnit,
                date: entryDate,
                sourceID: entryID
            )
        }
    }
}
