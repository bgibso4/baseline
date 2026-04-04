import Foundation
import SwiftData

@Model
class WeightEntry {
    var id: UUID
    var weight: Double
    var unit: String
    var date: Date
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(weight: Double, unit: String = "lb", date: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.weight = weight
        self.unit = unit
        self.date = Calendar.current.startOfDay(for: date)
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Weight converted to kilograms
    var weightInKg: Double {
        unit == "kg" ? weight : weight * 0.45359237
    }

    /// Weight converted to pounds
    var weightInLb: Double {
        unit == "lb" ? weight : weight / 0.45359237
    }
}
