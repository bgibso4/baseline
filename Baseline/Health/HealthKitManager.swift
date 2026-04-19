import Foundation
import HealthKit

// MARK: - HealthMirroring

/// The subset of HealthKit interactions the app's view models actually use.
/// Defined as a protocol so tests can substitute a spy and assert on the
/// exact sequence of save/delete calls without touching a real HK store.
///
/// All methods take primitive parameters (no SwiftData @Model references)
/// so view models can safely call them from inside unstructured Tasks
/// without capturing managed objects across actor boundaries.
protocol HealthMirroring: Sendable {
    func saveWeight(weight: Double, unit: String, date: Date, sourceID: UUID) async
    func saveScanMetrics(payload: InBodyPayload, date: Date, sourceID: UUID) async
    func saveWaistCircumference(valueCm: Double, date: Date, sourceID: UUID) async
    func deleteSamples(forSourceID id: UUID) async
}

// MARK: - HealthKitManager

/// Static façade for HealthKit access. View models call the static save/delete
/// methods; those route through the swappable `mirror` so tests can intercept.
/// Authorization, write-type inventory, and sample builders remain direct
/// static API because they don't need mocking.
enum HealthKitManager {

    /// When true, all HealthKit writes and deletes are suppressed. Used during
    /// test data seeding to prevent fake entries from polluting or destroying
    /// the user's Apple Health records.
    static var writesDisabled = false

    /// Active mirror implementation. Defaults to the live HealthKit-backed
    /// implementation in production; tests swap in a spy that records calls.
    nonisolated(unsafe) static var mirror: HealthMirroring = LiveHealthKitMirror()

    // MARK: - Types

    static let allWriteTypes: Set<HKSampleType> = {
        var types: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.leanBodyMass),
            HKQuantityType(.bodyMassIndex),
            HKQuantityType(.basalEnergyBurned),
        ]
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
            try await HKHealthStore().requestAuthorization(toShare: allWriteTypes, read: [])
            Log.health.info("HealthKit authorization requested")
        } catch {
            Log.health.error("HealthKit authorization failed", error)
        }
    }

    // MARK: - Mirror-routed API

    /// Convenience over `mirror.saveWeight(...)`. Extracts the primitive
    /// values from the entry so callers inside a `Task` don't need to
    /// unpack them manually.
    static func saveWeight(_ entry: WeightEntry) async {
        await mirror.saveWeight(
            weight: entry.weight,
            unit: entry.unit,
            date: entry.date,
            sourceID: entry.id
        )
    }

    /// Convenience over `mirror.saveScanMetrics(...)`. Decodes the scan's
    /// payload so callers don't repeat that boilerplate; if decoding fails,
    /// logs and no-ops (matches prior behaviour).
    static func saveScanMetrics(_ scan: Scan) async {
        guard let content = try? scan.decoded() else {
            Log.health.error("Failed to decode scan for HealthKit metrics")
            return
        }
        switch content {
        case .inBody(let payload):
            await mirror.saveScanMetrics(payload: payload, date: scan.date, sourceID: scan.id)
        }
    }

    static func saveWaistCircumference(valueCm: Double, date: Date, sourceID: UUID) async {
        await mirror.saveWaistCircumference(valueCm: valueCm, date: date, sourceID: sourceID)
    }

    static func deleteSamples(forSourceID id: UUID) async {
        await mirror.deleteSamples(forSourceID: id)
    }

    // MARK: - Metadata

    /// Builds the metadata dict that tags a sample with the originating
    /// Baseline record UUID. Used by `deleteSamples(forSourceID:)` to find
    /// and remove the samples when the record is edited or deleted.
    static func metadata(for sourceID: UUID?) -> [String: Any]? {
        guard let sourceID else { return nil }
        return [HKMetadataKeyExternalUUID: sourceID.uuidString]
    }

    // MARK: - Sample Builders (pure — safe to call from tests)

    static func buildWeightSample(
        weight: Double,
        unit: String,
        date: Date,
        sourceID: UUID? = nil
    ) -> HKQuantitySample {
        let hkUnit: HKUnit = unit == "kg" ? .gramUnit(with: .kilo) : .pound()
        let quantity = HKQuantity(unit: hkUnit, doubleValue: weight)
        return HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(for: sourceID)
        )
    }

    static func buildBodyFatSample(
        percentage: Double,
        date: Date,
        sourceID: UUID? = nil
    ) -> HKQuantitySample {
        // HealthKit expects body fat as a ratio (0.0-1.0), not a percentage
        let ratio = percentage / 100.0
        let quantity = HKQuantity(unit: .percent(), doubleValue: ratio)
        return HKQuantitySample(
            type: HKQuantityType(.bodyFatPercentage),
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(for: sourceID)
        )
    }

    static func buildLeanBodyMassSample(
        kg: Double,
        date: Date,
        sourceID: UUID? = nil
    ) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        return HKQuantitySample(
            type: HKQuantityType(.leanBodyMass),
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(for: sourceID)
        )
    }

    static func buildBMISample(
        bmi: Double,
        date: Date,
        sourceID: UUID? = nil
    ) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .count(), doubleValue: bmi)
        return HKQuantitySample(
            type: HKQuantityType(.bodyMassIndex),
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(for: sourceID)
        )
    }

    static func buildBMRSample(
        kcal: Double,
        date: Date,
        sourceID: UUID? = nil
    ) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        return HKQuantitySample(
            type: HKQuantityType(.basalEnergyBurned),
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(for: sourceID)
        )
    }

    static func buildWaistSample(
        valueCm: Double,
        date: Date,
        sourceID: UUID? = nil
    ) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .meterUnit(with: .centi), doubleValue: valueCm)
        return HKQuantitySample(
            type: HKQuantityType(.waistCircumference),
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(for: sourceID)
        )
    }
}

// MARK: - LiveHealthKitMirror

/// Production implementation — actually talks to HKHealthStore.
struct LiveHealthKitMirror: HealthMirroring {

    private let store = HKHealthStore()

    private var canWrite: Bool {
        !HealthKitManager.writesDisabled && HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Save

    func saveWeight(weight: Double, unit: String, date: Date, sourceID: UUID) async {
        guard canWrite else { return }
        let sample = HealthKitManager.buildWeightSample(
            weight: weight, unit: unit, date: date, sourceID: sourceID
        )
        await write(sample, label: "weight")
    }

    func saveScanMetrics(payload: InBodyPayload, date: Date, sourceID: UUID) async {
        guard canWrite else { return }
        await writeSample(
            HealthKitManager.buildBodyFatSample(percentage: payload.bodyFatPct, date: date, sourceID: sourceID),
            label: "body fat"
        )
        await writeSample(
            HealthKitManager.buildBMISample(bmi: payload.bmi, date: date, sourceID: sourceID),
            label: "BMI"
        )
        await writeSample(
            HealthKitManager.buildBMRSample(kcal: payload.basalMetabolicRate, date: date, sourceID: sourceID),
            label: "BMR"
        )
        if let leanMass = payload.leanBodyMassKg {
            await writeSample(
                HealthKitManager.buildLeanBodyMassSample(kg: leanMass, date: date, sourceID: sourceID),
                label: "lean body mass"
            )
        }
    }

    func saveWaistCircumference(valueCm: Double, date: Date, sourceID: UUID) async {
        guard canWrite else { return }
        let sample = HealthKitManager.buildWaistSample(
            valueCm: valueCm, date: date, sourceID: sourceID
        )
        await write(sample, label: "waist circumference")
    }

    // MARK: - Delete

    func deleteSamples(forSourceID id: UUID) async {
        guard canWrite else { return }
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            allowedValues: [id.uuidString]
        )
        for type in HealthKitManager.allWriteTypes {
            do {
                let count = try await store.deleteObjects(of: type, predicate: predicate)
                if count > 0 {
                    Log.health.debug("Deleted \(count) HK \(type.identifier) sample(s) for source \(id)")
                }
            } catch {
                Log.health.error("HK delete for type \(type.identifier) failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func writeSample(_ sample: HKQuantitySample, label: String) async {
        await write(sample, label: label)
    }

    private func write(_ sample: HKQuantitySample, label: String) async {
        do {
            try await store.save(sample)
            Log.health.debug("Saved \(label) to HealthKit")
        } catch {
            Log.health.error("Save \(label) to HealthKit failed", error)
        }
    }
}
