#if DEBUG
import Foundation
import SwiftData

private typealias BodyMeasurement = Baseline.Measurement

enum TestDataSeeder {

    // MARK: - Public API

    static func seed(context: ModelContext) {
        clearAll(context: context)
        seedWeightEntries(context: context)
        seedScans(context: context)
        seedMeasurements(context: context)
        try? context.save()
    }

    static func clearAll(context: ModelContext) {
        try? context.delete(model: WeightEntry.self)
        try? context.delete(model: Scan.self)
        try? context.delete(model: BodyMeasurement.self)
        try? context.save()
    }

    // MARK: - Weight Entries (~90 days)

    private static func seedWeightEntries(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startWeight = 205.0

        let notes: [Int: String] = [
            0: "Morning weigh-in",
            7: "Post workout",
            15: "Morning weigh-in",
            28: "After travel",
            45: "Post workout",
            60: "Morning weigh-in",
            75: "Post workout",
            88: "Morning weigh-in",
        ]

        for day in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -(89 - day), to: today) else { continue }

            // General downward trend: ~0.15 lb/day
            let trend = startWeight - Double(day) * 0.15

            // Plateau period: days 30-40 flatten out
            let plateauAdjustment: Double
            if day >= 30 && day <= 40 {
                plateauAdjustment = Double(day - 30) * 0.12 // counteracts the trend
            } else {
                plateauAdjustment = 0
            }

            // Daily fluctuation: sine wave + deterministic offset
            let sineWave = sin(Double(day) * 0.8) * 0.7
            let pseudoRandom = sin(Double(day) * 3.7 + 1.3) * 0.4
            let fluctuation = sineWave + pseudoRandom

            let weight = trend + plateauAdjustment + fluctuation
            let roundedWeight = (weight * 10).rounded() / 10

            let entry = WeightEntry(
                weight: roundedWeight,
                unit: "lb",
                date: date,
                notes: notes[day]
            )
            context.insert(entry)
        }
    }

    // MARK: - InBody Scans (3)

    private static func seedScans(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lbToKg = 0.45359237

        struct ScanData {
            let dayOffset: Int   // days before today (from end of 90-day window)
            let weightLb: Double
            let bodyFatPct: Double
            let smmLb: Double
            let bfmLb: Double
            let tbwL: Double
            let bmi: Double
            let bmr: Double
        }

        let scans: [ScanData] = [
            ScanData(dayOffset: 89, weightLb: 205.0, bodyFatPct: 22.5, smmLb: 82.0,
                     bfmLb: 46.1, tbwL: 96.0, bmi: 27.8, bmr: 1850),
            ScanData(dayOffset: 44, weightLb: 198.0, bodyFatPct: 20.8, smmLb: 83.5,
                     bfmLb: 41.2, tbwL: 97.5, bmi: 26.9, bmr: 1870),
            ScanData(dayOffset: 4, weightLb: 192.0, bodyFatPct: 19.2, smmLb: 84.0,
                     bfmLb: 36.9, tbwL: 98.0, bmi: 26.1, bmr: 1880),
        ]

        for scan in scans {
            guard let date = calendar.date(byAdding: .day, value: -scan.dayOffset, to: today) else { continue }

            let payload = InBodyPayload(
                weightKg: scan.weightLb * lbToKg,
                skeletalMuscleMassKg: scan.smmLb * lbToKg,
                bodyFatMassKg: scan.bfmLb * lbToKg,
                bodyFatPct: scan.bodyFatPct,
                totalBodyWaterL: scan.tbwL,
                bmi: scan.bmi,
                basalMetabolicRate: scan.bmr
            )

            guard let data = try? JSONEncoder().encode(payload) else { continue }

            let entry = Scan(date: date, type: .inBody, source: .manual, payload: data)
            context.insert(entry)
        }
    }

    // MARK: - Tape Measurements

    private static func seedMeasurements(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let inToCm = 2.54

        struct MeasData {
            let dayOffset: Int
            let type: MeasurementType
            let inches: Double
        }

        let measurements: [MeasData] = [
            // Waist: 36.0" down to 34.5"
            MeasData(dayOffset: 89, type: .waist, inches: 36.0),
            MeasData(dayOffset: 60, type: .waist, inches: 35.5),
            MeasData(dayOffset: 30, type: .waist, inches: 35.0),
            MeasData(dayOffset: 4,  type: .waist, inches: 34.5),
            // Chest: 42.0" (2 entries)
            MeasData(dayOffset: 89, type: .chest, inches: 42.0),
            MeasData(dayOffset: 30, type: .chest, inches: 42.0),
            // Neck: 16.5" (2 entries)
            MeasData(dayOffset: 89, type: .neck, inches: 16.5),
            MeasData(dayOffset: 30, type: .neck, inches: 16.5),
        ]

        for m in measurements {
            guard let date = calendar.date(byAdding: .day, value: -m.dayOffset, to: today) else { continue }

            let entry = BodyMeasurement(
                date: date,
                type: m.type,
                valueCm: m.inches * inToCm
            )
            context.insert(entry)
        }
    }
}
#endif
