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

    func saveMeasurement(type: MeasurementType, valueCm: Double, notes: String? = nil) {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        let measurement = Measurement(date: Date(), type: type, valueCm: valueCm, notes: notesToSave)
        modelContext.insert(measurement)
        try? modelContext.save()

        if type == .waist {
            Task {
                await HealthKitManager.saveWaistCircumference(valueCm: valueCm, date: Date())
            }
        }

        refresh()
    }

    func deleteMeasurement(_ measurement: Measurement) {
        modelContext.delete(measurement)
        try? modelContext.save()
        refresh()
    }

    // MARK: - Scans

    func saveScan(type: ScanType, source: ScanSource, payload: Encodable, notes: String? = nil) {
        guard let data = try? JSONEncoder().encode(AnyEncodable(payload)) else { return }
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        let scan = Scan(date: Date(), type: type, source: source, payload: data, notes: notesToSave)
        modelContext.insert(scan)
        try? modelContext.save()

        Task {
            await HealthKitManager.saveScanMetrics(scan)
        }

        refresh()
    }

    func deleteScan(_ scan: Scan) {
        modelContext.delete(scan)
        try? modelContext.save()
        refresh()
    }

    // MARK: - Helpers

    func latestValue(for type: MeasurementType) -> Measurement? {
        latestMeasurements.first { $0.measurementType == type }
    }

    func decodedPayload(for scan: Scan) -> ScanContent? {
        try? scan.decoded()
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
