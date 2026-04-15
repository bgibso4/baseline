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

    /// Check if a weigh-in already exists for the given date.
    func existingEntry(for date: Date) -> WeightEntry? {
        let targetDay = Calendar.current.startOfDay(for: date)
        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == targetDay }
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
        let targetDay = Calendar.current.startOfDay(for: date)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == targetDay }
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

        Task {
            await HealthKitManager.saveWeight(
                WeightEntry(weight: currentWeight, unit: unit, date: date)
            )
        }
    }
}
