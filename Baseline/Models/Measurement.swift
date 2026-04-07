import Foundation
import SwiftData

@Model
final class Measurement {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String = ""
    var valueCm: Double = 0
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
