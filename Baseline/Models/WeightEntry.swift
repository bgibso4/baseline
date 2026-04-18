import Foundation
import SwiftData

@Model
class WeightEntry {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var weight: Double = 0
    var unit: String = "lb"
    var date: Date = Date()
    @Attribute(.allowsCloudEncryption) var notes: String?
    @Attribute(.externalStorage, .allowsCloudEncryption) var photoData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(weight: Double, unit: String = "lb", date: Date = Date(), notes: String? = nil, photoData: Data? = nil) {
        self.id = UUID()
        self.weight = weight
        self.unit = unit
        self.date = date
        self.notes = notes
        self.photoData = photoData
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
