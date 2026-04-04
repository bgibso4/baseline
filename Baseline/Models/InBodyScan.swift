import Foundation
import SwiftData

@Model
class InBodyScan {
    var id: UUID
    var date: Date
    var weight: Double
    var unit: String
    var bodyFatPercentage: Double?
    var skeletalMuscleMass: Double?
    var bodyFatMass: Double?
    var bmi: Double?
    var totalBodyWater: Double?
    var leanBodyMass: Double?
    var basalMetabolicRate: Double?
    var inBodyScore: Double?
    var rightArmLean: Double?
    var leftArmLean: Double?
    var trunkLean: Double?
    var rightLegLean: Double?
    var leftLegLean: Double?
    var rightArmFat: Double?
    var leftArmFat: Double?
    var trunkFat: Double?
    var rightLegFat: Double?
    var leftLegFat: Double?
    var rawOcrText: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(date: Date, weight: Double, unit: String = "lb") {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.weight = weight
        self.unit = unit
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func toBodyMeasurements() -> [BodyMeasurement] {
        var measurements: [BodyMeasurement] = []

        let pairs: [(MeasurementType, Double?, String)] = [
            (.bodyFatPercentage, bodyFatPercentage, "%"),
            (.skeletalMuscleMass, skeletalMuscleMass, unit),
            (.bodyFatMass, bodyFatMass, unit),
            (.leanBodyMass, leanBodyMass, unit),
            (.bmi, bmi, ""),
            (.totalBodyWater, totalBodyWater, "L"),
            (.basalMetabolicRate, basalMetabolicRate, ""),
            (.inBodyScore, inBodyScore, ""),
            (.rightArmLean, rightArmLean, unit),
            (.leftArmLean, leftArmLean, unit),
            (.trunkLean, trunkLean, unit),
            (.rightLegLean, rightLegLean, unit),
            (.leftLegLean, leftLegLean, unit),
            (.rightArmFat, rightArmFat, unit),
            (.leftArmFat, leftArmFat, unit),
            (.trunkFat, trunkFat, unit),
            (.rightLegFat, rightLegFat, unit),
            (.leftLegFat, leftLegFat, unit),
        ]

        for (type, value, measureUnit) in pairs {
            if let value {
                measurements.append(BodyMeasurement(
                    date: date,
                    type: type,
                    value: value,
                    unit: measureUnit,
                    source: .inbody
                ))
            }
        }

        return measurements
    }
}
