import Foundation
import SwiftData
import Observation

@Observable
class WeighInViewModel {
    private let modelContext: ModelContext
    let unit: String

    var currentWeight: Double
    var stepSize: Double = 0.1

    private let stepSizes: [Double] = [0.1, 0.5, 1.0]

    init(modelContext: ModelContext, lastWeight: Double?, unit: String) {
        self.modelContext = modelContext
        self.unit = unit
        self.currentWeight = lastWeight ?? (unit == "kg" ? 70.0 : 150.0)
    }

    func increment() {
        currentWeight = (currentWeight + stepSize).rounded(toPlaces: 1)
    }

    func decrement() {
        currentWeight = (currentWeight - stepSize).rounded(toPlaces: 1)
    }

    func cycleStepSize() {
        guard let currentIndex = stepSizes.firstIndex(of: stepSize) else {
            stepSize = stepSizes[0]
            return
        }
        let nextIndex = (currentIndex + 1) % stepSizes.count
        stepSize = stepSizes[nextIndex]
    }

    func save() {
        let today = Calendar.current.startOfDay(for: Date())

        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == today }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.weight = currentWeight
            existing.updatedAt = Date()
        } else {
            let entry = WeightEntry(weight: currentWeight, unit: unit, date: Date())
            modelContext.insert(entry)
        }

        try? modelContext.save()
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
