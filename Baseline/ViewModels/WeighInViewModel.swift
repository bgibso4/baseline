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

    func increment() {
        currentWeight = (currentWeight + 0.1).rounded(toPlaces: 1)
    }

    func decrement() {
        currentWeight = (currentWeight - 0.1).rounded(toPlaces: 1)
    }

    func save(date: Date = Date()) {
        let targetDay = Calendar.current.startOfDay(for: date)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == targetDay }
        )
        descriptor.fetchLimit = 1

        let savedEntry: WeightEntry
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.weight = currentWeight
            existing.notes = notesToSave
            existing.updatedAt = Date()
            savedEntry = existing
        } else {
            let entry = WeightEntry(weight: currentWeight, unit: unit, date: date, notes: notesToSave)
            modelContext.insert(entry)
            savedEntry = entry
        }

        try? modelContext.save()
        SyncHelper.mirrorRecord(savedEntry)

        Task {
            await HealthKitManager.saveWeight(
                WeightEntry(weight: currentWeight, unit: unit, date: date)
            )
        }
    }
}
