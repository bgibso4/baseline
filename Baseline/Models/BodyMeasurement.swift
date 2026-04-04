import Foundation
import SwiftData

@Model
class BodyMeasurement {
    var id: UUID
    var date: Date
    var type: String
    var value: Double
    var unit: String
    var source: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date,
        type: MeasurementType,
        value: Double,
        unit: String? = nil,
        source: MeasurementSource = .manual,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.type = type.rawValue
        self.value = value
        self.unit = unit ?? type.defaultUnit
        self.source = source.rawValue
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var measurementType: MeasurementType? {
        MeasurementType(rawValue: type)
    }

    var measurementSource: MeasurementSource? {
        MeasurementSource(rawValue: source)
    }
}
