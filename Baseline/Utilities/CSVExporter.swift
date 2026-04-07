import Foundation
import SwiftData

enum CSVExporter {

    // MARK: - Weight Entries

    static func exportWeights(context: ModelContext) -> String {
        let header = "date,weight,unit,notes"
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else {
            return header
        }

        let rows = entries.map { entry in
            let dateStr = DateFormatting.iso8601(entry.date)
            let notes = escapeCSV(entry.notes ?? "")
            return "\(dateStr),\(entry.weight),\(entry.unit),\(notes)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Measurements

    static func exportMeasurements(context: ModelContext) -> String {
        let header = "date,type,valueCm,notes"
        let descriptor = FetchDescriptor<Measurement>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else {
            return header
        }

        let rows = entries.map { m in
            let dateStr = DateFormatting.iso8601(m.date)
            let notes = escapeCSV(m.notes ?? "")
            return "\(dateStr),\(m.type),\(m.valueCm),\(notes)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Scans

    static func exportScans(context: ModelContext) -> String {
        let header = "date,type,source,weightKg,skeletalMuscleMassKg,bodyFatMassKg,bodyFatPct,totalBodyWaterL,bmi,basalMetabolicRate"
        let descriptor = FetchDescriptor<Scan>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        guard let scans = try? context.fetch(descriptor), !scans.isEmpty else {
            return header
        }

        let rows = scans.compactMap { scan -> String? in
            let dateStr = DateFormatting.iso8601(scan.date)
            guard let content = try? scan.decoded() else { return nil }
            switch content {
            case .inBody(let p):
                return "\(dateStr),\(scan.type),\(scan.source),\(p.weightKg),\(p.skeletalMuscleMassKg),\(p.bodyFatMassKg),\(p.bodyFatPct),\(p.totalBodyWaterL),\(p.bmi),\(p.basalMetabolicRate)"
            }
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func escapeCSV(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
