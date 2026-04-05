import Foundation
import SwiftData

@Model
final class Measurement {
    var id: UUID
    var date: Date
    var type: String
    var valueCm: Double
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(date: Date, type: MeasurementType, valueCm: Double, notes: String? = nil) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.type = type.rawValue
        self.valueCm = valueCm
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var measurementType: MeasurementType? { MeasurementType(rawValue: type) }
}
