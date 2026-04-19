import Foundation
import SwiftData
import Observation

@Observable
class BodyViewModel {
    private let modelContext: ModelContext

    var latestMeasurements: [Measurement] = []
    var recentScans: [Scan] = []
    var scanCount: Int { recentScans.count }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        loadLatestMeasurements()
        loadRecentScans()
    }

    // MARK: - Tape Measurements

    func saveMeasurement(type: MeasurementType, valueCm: Double, date: Date = Date(), notes: String? = nil) {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        let measurement = Measurement(date: date, type: type, valueCm: valueCm, notes: notesToSave)
        modelContext.insert(measurement)
        do {
            try modelContext.save()
            Log.data.info("Saved \(type.rawValue) measurement: \(valueCm) cm")
        } catch {
            Log.data.error("Save measurement failed", error)
        }
        SyncHelper.mirrorRecord(measurement)

        if type == .waist {
            Task {
                await HealthKitManager.saveWaistCircumference(valueCm: valueCm, date: Date())
            }
        }

        // Auto-complete any matching goal (body fat %, waist, lean mass, etc.).
        // Goals are stored in the user's display unit — convert cm to the
        // preferred length unit before checking.
        let lengthPref = UserDefaults.standard.string(forKey: "lengthUnit") ?? "in"
        let displayValue = lengthPref == "cm" ? valueCm : UnitConversion.cmToIn(valueCm)
        GoalAutoCompleter.checkCompletions(
            values: [type.trendMetric.rawValue: displayValue],
            in: modelContext
        )

        refresh()
    }

    func deleteMeasurement(_ measurement: Measurement) {
        modelContext.delete(measurement)
        do {
            try modelContext.save()
            Log.data.info("Deleted measurement")
        } catch {
            Log.data.error("Delete measurement failed", error)
        }
        refresh()
    }

    // MARK: - Scans

    func saveScan(type: ScanType, source: ScanSource, payload: Encodable, notes: String? = nil) {
        guard let data = try? JSONEncoder().encode(AnyEncodable(payload)) else {
            Log.scan.error("Failed to encode scan payload")
            return
        }
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        let scan = Scan(date: Date(), type: type, source: source, payload: data, notes: notesToSave)
        modelContext.insert(scan)
        do {
            try modelContext.save()
            Log.data.info("Saved \(type.rawValue) scan via \(source.rawValue)")
        } catch {
            Log.data.error("Save scan failed", error)
        }
        SyncHelper.mirrorRecord(scan)

        Task {
            await HealthKitManager.saveScanMetrics(scan)
        }

        refresh()
    }

    func deleteScan(_ scan: Scan) {
        modelContext.delete(scan)
        do {
            try modelContext.save()
            Log.data.info("Deleted scan")
        } catch {
            Log.data.error("Delete scan failed", error)
        }
        refresh()
    }

    func updateScan(_ scan: Scan, payload: Data) {
        scan.payloadData = payload
        scan.updatedAt = Date()
        do {
            try modelContext.save()
            Log.data.info("Updated scan payload")
        } catch {
            Log.data.error("Update scan failed", error)
        }
        refresh()
    }

    // MARK: - Helpers

    func latestValue(for type: MeasurementType) -> Measurement? {
        latestMeasurements.first { $0.measurementType == type }
    }

    func decodedPayload(for scan: Scan) -> ScanContent? {
        try? scan.decoded()
    }

    /// Fetch all measurements of a given type (reverse chronological).
    func allMeasurements(ofType type: MeasurementType) -> [Measurement] {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<Measurement>(
            predicate: #Predicate { $0.type == typeRaw },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Private

    private func loadLatestMeasurements() {
        var descriptor = FetchDescriptor<Measurement>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let all = try? modelContext.fetch(descriptor) else {
            latestMeasurements = []
            return
        }

        var seen = Set<String>()
        var latest: [Measurement] = []
        for m in all {
            if seen.insert(m.type).inserted {
                latest.append(m)
            }
        }
        latestMeasurements = latest
    }

    private func loadRecentScans() {
        var descriptor = FetchDescriptor<Scan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        recentScans = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Type-Erased Encodable Wrapper

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeFunc = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
