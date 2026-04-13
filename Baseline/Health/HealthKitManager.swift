import Foundation
import HealthKit

enum HealthKitManager {

    private static let store = HKHealthStore()

    // MARK: - Types

    static let allWriteTypes: Set<HKSampleType> = {
        var types: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.leanBodyMass),
            HKQuantityType(.bodyMassIndex),
            HKQuantityType(.basalEnergyBurned),
        ]
        if #available(iOS 18.0, *) {
            // waistCircumference available iOS 18+
        }
        types.insert(HKQuantityType(.waistCircumference))
        return types
    }()

    // MARK: - Authorization

    static func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: allWriteTypes, read: [])
    }

    // MARK: - Weight

    static func saveWeight(_ entry: WeightEntry) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sample = buildWeightSample(weight: entry.weight, unit: entry.unit, date: entry.date)
        try? await store.save(sample)
    }

    static func buildWeightSample(weight: Double, unit: String, date: Date) -> HKQuantitySample {
        let hkUnit: HKUnit = unit == "kg" ? .gramUnit(with: .kilo) : .pound()
        let quantity = HKQuantity(unit: hkUnit, doubleValue: weight)
        return HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: quantity,
            start: date,
            end: date
        )
    }

    // MARK: - Body Fat

    static func saveBodyFat(percentage: Double, date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sample = buildBodyFatSample(percentage: percentage, date: date)
        try? await store.save(sample)
    }

    static func buildBodyFatSample(percentage: Double, date: Date) -> HKQuantitySample {
        // HealthKit expects body fat as a ratio (0.0-1.0), not a percentage
        let ratio = percentage / 100.0
        let quantity = HKQuantity(unit: .percent(), doubleValue: ratio)
        return HKQuantitySample(
            type: HKQuantityType(.bodyFatPercentage),
            quantity: quantity,
            start: date,
            end: date
        )
    }

    // MARK: - Lean Body Mass

    static func saveLeanBodyMass(kg: Double, date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sample = buildLeanBodyMassSample(kg: kg, date: date)
        try? await store.save(sample)
    }

    static func buildLeanBodyMassSample(kg: Double, date: Date) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        return HKQuantitySample(
            type: HKQuantityType(.leanBodyMass),
            quantity: quantity,
            start: date,
            end: date
        )
    }

    // MARK: - BMI

    static func saveBMI(_ bmi: Double, date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sample = buildBMISample(bmi: bmi, date: date)
        try? await store.save(sample)
    }

    static func buildBMISample(bmi: Double, date: Date) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .count(), doubleValue: bmi)
        return HKQuantitySample(
            type: HKQuantityType(.bodyMassIndex),
            quantity: quantity,
            start: date,
            end: date
        )
    }

    // MARK: - Basal Metabolic Rate

    static func saveBMR(kcal: Double, date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sample = buildBMRSample(kcal: kcal, date: date)
        try? await store.save(sample)
    }

    static func buildBMRSample(kcal: Double, date: Date) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        return HKQuantitySample(
            type: HKQuantityType(.basalEnergyBurned),
            quantity: quantity,
            start: date,
            end: date
        )
    }

    // MARK: - Waist Circumference

    static func saveWaistCircumference(valueCm: Double, date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sample = buildWaistSample(valueCm: valueCm, date: date)
        try? await store.save(sample)
    }

    static func buildWaistSample(valueCm: Double, date: Date) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .meterUnit(with: .centi), doubleValue: valueCm)
        return HKQuantitySample(
            type: HKQuantityType(.waistCircumference),
            quantity: quantity,
            start: date,
            end: date
        )
    }

    // MARK: - Scan Metrics (composite)

    static func saveScanMetrics(_ scan: Scan) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let content = try? scan.decoded() else { return }
        switch content {
        case .inBody(let payload):
            await saveBodyFat(percentage: payload.bodyFatPct, date: scan.date)
            await saveBMI(payload.bmi, date: scan.date)
            await saveBMR(kcal: payload.basalMetabolicRate, date: scan.date)
            if let leanMass = payload.leanBodyMassKg {
                await saveLeanBodyMass(kg: leanMass, date: scan.date)
            }
        }
    }
}
