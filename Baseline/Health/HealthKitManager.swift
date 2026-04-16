import Foundation
import HealthKit

enum HealthKitManager {

    private static let store = HKHealthStore()

    /// When true, all HealthKit writes are suppressed. Used during test data
    /// seeding to prevent fake entries from polluting the user's Apple Health.
    static var writesDisabled = false

    private static var canWrite: Bool {
        !writesDisabled && HKHealthStore.isHealthDataAvailable()
    }

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
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.info("HealthKit not available on this device")
            return
        }
        do {
            try await store.requestAuthorization(toShare: allWriteTypes, read: [])
            Log.health.info("HealthKit authorization requested")
        } catch {
            Log.health.error("HealthKit authorization failed", error)
        }
    }

    // MARK: - Weight

    static func saveWeight(_ entry: WeightEntry) async {
        guard canWrite else { return }
        let sample = buildWeightSample(weight: entry.weight, unit: entry.unit, date: entry.date)
        do {
            try await store.save(sample)
            Log.health.debug("Saved weight to HealthKit")
        } catch {
            Log.health.error("Save weight to HealthKit failed", error)
        }
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
        guard canWrite else { return }
        let sample = buildBodyFatSample(percentage: percentage, date: date)
        do {
            try await store.save(sample)
            Log.health.debug("Saved body fat to HealthKit")
        } catch {
            Log.health.error("Save body fat to HealthKit failed", error)
        }
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
        guard canWrite else { return }
        let sample = buildLeanBodyMassSample(kg: kg, date: date)
        do {
            try await store.save(sample)
            Log.health.debug("Saved lean body mass to HealthKit")
        } catch {
            Log.health.error("Save lean body mass to HealthKit failed", error)
        }
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
        guard canWrite else { return }
        let sample = buildBMISample(bmi: bmi, date: date)
        do {
            try await store.save(sample)
            Log.health.debug("Saved BMI to HealthKit")
        } catch {
            Log.health.error("Save BMI to HealthKit failed", error)
        }
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
        guard canWrite else { return }
        let sample = buildBMRSample(kcal: kcal, date: date)
        do {
            try await store.save(sample)
            Log.health.debug("Saved BMR to HealthKit")
        } catch {
            Log.health.error("Save BMR to HealthKit failed", error)
        }
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
        guard canWrite else { return }
        let sample = buildWaistSample(valueCm: valueCm, date: date)
        do {
            try await store.save(sample)
            Log.health.debug("Saved waist circumference to HealthKit")
        } catch {
            Log.health.error("Save waist circumference to HealthKit failed", error)
        }
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
        guard canWrite else { return }
        guard let content = try? scan.decoded() else {
            Log.health.error("Failed to decode scan for HealthKit metrics")
            return
        }
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
