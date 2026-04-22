import Foundation
import SwiftData

// MARK: - Public Types

/// Row-level parse problem. Returned alongside successful rows so the
/// caller can surface them to the user without aborting the whole import.
struct CSVParseIssue: Equatable {
    let line: Int
    let reason: String
}

/// Typed output of parsing one CSV blob.
struct CSVParseResult<Row: Equatable>: Equatable {
    let rows: [Row]
    let issues: [CSVParseIssue]
}

struct CSVWeightRow: Equatable {
    let date: Date
    let weight: Double
    let unit: String
    let notes: String?
}

struct CSVMeasurementRow: Equatable {
    let date: Date
    let type: MeasurementType
    let valueCm: Double
    let notes: String?
}

struct CSVScanRow: Equatable {
    let date: Date
    let type: ScanType
    let source: ScanSource
    let payload: InBodyPayload
}

enum CSVImportError: Error, Equatable {
    case emptyFile
    case missingOrMalformedHeader(expected: String, found: String)
}

/// Format the CSV's header identifies. Import UI uses this to dispatch to
/// the right parser + persistence path.
enum CSVFormat: String {
    case weights
    case measurements
    case scans

    var expectedHeader: String {
        switch self {
        case .weights:
            return "date,weight,unit,notes"
        case .measurements:
            return "date,type,valueCm,notes"
        case .scans:
            return "date,type,source,weightKg,skeletalMuscleMassKg,bodyFatMassKg,bodyFatPct,totalBodyWaterL,bmi,basalMetabolicRate"
        }
    }

    static func detect(from csv: String) -> CSVFormat? {
        // Strip UTF-8 BOM (Excel adds it) + normalise line endings before
        // slicing the first line.
        let cleaned = csv.stripBOM()
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let firstLine = cleaned.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        let header = firstLine.trimmingCharacters(in: .whitespaces)
        for format in [CSVFormat.weights, .measurements, .scans] where header == format.expectedHeader {
            return format
        }
        return nil
    }
}

/// How to handle rows whose (type, day) collides with existing data.
enum ConflictStrategy {
    /// Leave existing data untouched; skip the imported row.
    case skip
    /// Delete existing data (and its HealthKit samples) and persist the imported row.
    case overwrite
}

/// Union of parsed-result types. Lets the UI (and dispatch helpers) hold
/// a single state slot regardless of which format the user picked.
enum ParsedImport {
    case weights(CSVParseResult<CSVWeightRow>)
    case measurements(CSVParseResult<CSVMeasurementRow>)
    case scans(CSVParseResult<CSVScanRow>)

    var format: CSVFormat {
        switch self {
        case .weights: return .weights
        case .measurements: return .measurements
        case .scans: return .scans
        }
    }

    var rowCount: Int {
        switch self {
        case .weights(let r): return r.rows.count
        case .measurements(let r): return r.rows.count
        case .scans(let r): return r.rows.count
        }
    }

    var issues: [CSVParseIssue] {
        switch self {
        case .weights(let r): return r.issues
        case .measurements(let r): return r.issues
        case .scans(let r): return r.issues
        }
    }
}

/// Error for `CSVImporter.parseAny` — distinguishes "I couldn't detect the
/// format" from the lower-level parse errors.
enum CSVDispatchError: Error, Equatable {
    case unknownFormat
    case parseFailed(CSVImportError)
}

/// Per-format counts returned from `import*` functions so the UI can summarize.
struct ImportOutcome: Equatable {
    var inserted: Int = 0
    var overwritten: Int = 0
    var skipped: Int = 0
    var failed: Int = 0

    static var empty: ImportOutcome { ImportOutcome() }
}

// MARK: - String helpers

private extension String {
    /// Removes a leading UTF-8 BOM (`U+FEFF`) if present. Excel writes one
    /// when exporting CSVs on macOS — silently breaking header matching.
    func stripBOM() -> String {
        guard hasPrefix("\u{FEFF}") else { return self }
        return String(dropFirst())
    }
}

// MARK: - Importer

enum CSVImporter {

    // MARK: - Format dispatch

    /// Detects the format from the header and dispatches to the right
    /// parser. Extracted from the view layer so tests can exercise the
    /// full pick → parse → persist flow without SwiftUI machinery.
    static func parseAny(_ csv: String) -> Result<ParsedImport, CSVDispatchError> {
        guard let format = CSVFormat.detect(from: csv) else {
            return .failure(.unknownFormat)
        }
        switch format {
        case .weights:
            return parseWeights(csv)
                .map(ParsedImport.weights)
                .mapError(CSVDispatchError.parseFailed)
        case .measurements:
            return parseMeasurements(csv)
                .map(ParsedImport.measurements)
                .mapError(CSVDispatchError.parseFailed)
        case .scans:
            return parseScans(csv)
                .map(ParsedImport.scans)
                .mapError(CSVDispatchError.parseFailed)
        }
    }

    /// Runs the appropriate per-format import for a `ParsedImport`.
    @discardableResult
    static func importAny(
        _ parsed: ParsedImport,
        context: ModelContext,
        conflictStrategy: ConflictStrategy
    ) -> ImportOutcome {
        switch parsed {
        case .weights(let r):
            return importWeights(r.rows, context: context, conflictStrategy: conflictStrategy)
        case .measurements(let r):
            return importMeasurements(r.rows, context: context, conflictStrategy: conflictStrategy)
        case .scans(let r):
            return importScans(r.rows, context: context, conflictStrategy: conflictStrategy)
        }
    }

    // MARK: - Weights

    static func parseWeights(_ csv: String) -> Result<CSVParseResult<CSVWeightRow>, CSVImportError> {
        parse(csv, expected: CSVFormat.weights) { lineNumber, columns in
            guard columns.count >= 3 else {
                throw ParseRowError("expected 3+ columns, found \(columns.count)")
            }
            guard let date = DateFormatting.fromISO8601(columns[0]) else {
                throw ParseRowError("invalid date: \(columns[0])")
            }
            guard let weight = Double(columns[1]), weight > 0 else {
                throw ParseRowError("invalid weight: \(columns[1])")
            }
            let unit = columns[2].trimmingCharacters(in: .whitespaces)
            guard unit == "lb" || unit == "kg" else {
                throw ParseRowError("unit must be 'lb' or 'kg', got '\(unit)'")
            }
            let notes: String? = (columns.count >= 4 && !columns[3].isEmpty) ? columns[3] : nil
            return CSVWeightRow(date: date, weight: weight, unit: unit, notes: notes)
        }
    }

    // MARK: - Measurements

    static func parseMeasurements(_ csv: String) -> Result<CSVParseResult<CSVMeasurementRow>, CSVImportError> {
        parse(csv, expected: CSVFormat.measurements) { lineNumber, columns in
            guard columns.count >= 3 else {
                throw ParseRowError("expected 3+ columns, found \(columns.count)")
            }
            guard let date = DateFormatting.fromISO8601(columns[0]) else {
                throw ParseRowError("invalid date: \(columns[0])")
            }
            guard let type = MeasurementType(rawValue: columns[1]) else {
                throw ParseRowError("unknown measurement type: \(columns[1])")
            }
            guard let valueCm = Double(columns[2]), valueCm > 0 else {
                throw ParseRowError("invalid valueCm: \(columns[2])")
            }
            let notes: String? = (columns.count >= 4 && !columns[3].isEmpty) ? columns[3] : nil
            return CSVMeasurementRow(date: date, type: type, valueCm: valueCm, notes: notes)
        }
    }

    // MARK: - Scans

    static func parseScans(_ csv: String) -> Result<CSVParseResult<CSVScanRow>, CSVImportError> {
        parse(csv, expected: CSVFormat.scans) { lineNumber, columns in
            guard columns.count >= 10 else {
                throw ParseRowError("expected 10 columns, found \(columns.count)")
            }
            guard let date = DateFormatting.fromISO8601(columns[0]) else {
                throw ParseRowError("invalid date: \(columns[0])")
            }
            guard let type = ScanType(rawValue: columns[1]) else {
                throw ParseRowError("unknown scan type: \(columns[1])")
            }
            guard let source = ScanSource(rawValue: columns[2]) else {
                throw ParseRowError("unknown scan source: \(columns[2])")
            }
            // Columns 3..9 are the InBody core fields (weightKg, SMM, BFM,
            // PBF, TBW, BMI, BMR). Tag source as `.imported` so the app
            // distinguishes them from live OCR scans on display.
            guard let weightKg = Double(columns[3]), weightKg > 0 else {
                throw ParseRowError("invalid weightKg: \(columns[3])")
            }
            guard let smm = Double(columns[4]), smm >= 0 else {
                throw ParseRowError("invalid skeletalMuscleMassKg: \(columns[4])")
            }
            guard let bfm = Double(columns[5]), bfm >= 0 else {
                throw ParseRowError("invalid bodyFatMassKg: \(columns[5])")
            }
            guard let pbf = Double(columns[6]), pbf >= 0 else {
                throw ParseRowError("invalid bodyFatPct: \(columns[6])")
            }
            guard let tbw = Double(columns[7]), tbw >= 0 else {
                throw ParseRowError("invalid totalBodyWaterL: \(columns[7])")
            }
            guard let bmi = Double(columns[8]), bmi > 0 else {
                throw ParseRowError("invalid bmi: \(columns[8])")
            }
            guard let bmr = Double(columns[9]), bmr >= 0 else {
                throw ParseRowError("invalid basalMetabolicRate: \(columns[9])")
            }
            let payload = InBodyPayload(
                weightKg: weightKg,
                skeletalMuscleMassKg: smm,
                bodyFatMassKg: bfm,
                bodyFatPct: pbf,
                totalBodyWaterL: tbw,
                bmi: bmi,
                basalMetabolicRate: bmr
            )
            return CSVScanRow(date: date, type: type, source: source, payload: payload)
        }
    }

    // MARK: - Persistence

    /// Insert parsed weight rows into the context. Fires HealthKit mirror
    /// tasks for each persisted entry so the UUID-tagged samples match the
    /// single-entry save path. Returns per-row outcome counts.
    @discardableResult
    static func importWeights(
        _ rows: [CSVWeightRow],
        context: ModelContext,
        conflictStrategy: ConflictStrategy
    ) -> ImportOutcome {
        var outcome = ImportOutcome.empty
        for row in rows {
            let dayStart = Calendar.current.startOfDay(for: row.date)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            var descriptor = FetchDescriptor<WeightEntry>(
                predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }
            )
            descriptor.fetchLimit = 1
            let existing = (try? context.fetch(descriptor))?.first

            if let existing {
                switch conflictStrategy {
                case .skip:
                    outcome.skipped += 1
                    continue
                case .overwrite:
                    let staleID = existing.id
                    context.delete(existing)
                    Task { await HealthKitManager.mirror.deleteSamples(forSourceID: staleID) }
                    outcome.overwritten += 1
                }
            } else {
                outcome.inserted += 1
            }

            let entry = WeightEntry(
                weight: row.weight,
                unit: row.unit,
                date: row.date,
                notes: row.notes
            )
            context.insert(entry)

            do {
                try context.save()
            } catch {
                Log.data.error("CSV weight import save failed", error)
                outcome.failed += 1
                // Don't break — continue with remaining rows.
                continue
            }
            SyncHelper.mirrorRecord(entry)

            let entryID = entry.id
            let entryWeight = entry.weight
            let entryUnit = entry.unit
            let entryDate = entry.date
            Task {
                await HealthKitManager.mirror.deleteSamples(forSourceID: entryID)
                await HealthKitManager.mirror.saveWeight(
                    weight: entryWeight,
                    unit: entryUnit,
                    date: entryDate,
                    sourceID: entryID
                )
            }
        }
        Log.data.info("CSV weight import: inserted=\(outcome.inserted) overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
        return outcome
    }

    /// Insert parsed measurement rows. Conflict is per (type, day). Fires
    /// HealthKit mirror for waist rows only (matches BodyViewModel).
    @discardableResult
    static func importMeasurements(
        _ rows: [CSVMeasurementRow],
        context: ModelContext,
        conflictStrategy: ConflictStrategy
    ) -> ImportOutcome {
        var outcome = ImportOutcome.empty
        for row in rows {
            let day = Calendar.current.startOfDay(for: row.date)
            let typeRaw = row.type.rawValue
            let descriptor = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.date == day && $0.type == typeRaw }
            )
            let existing = (try? context.fetch(descriptor)) ?? []

            if !existing.isEmpty {
                switch conflictStrategy {
                case .skip:
                    outcome.skipped += 1
                    continue
                case .overwrite:
                    for conflict in existing {
                        let staleID = conflict.id
                        let wasWaist = conflict.measurementType == .waist
                        context.delete(conflict)
                        if wasWaist {
                            Task { await HealthKitManager.mirror.deleteSamples(forSourceID: staleID) }
                        }
                    }
                    outcome.overwritten += 1
                }
            } else {
                outcome.inserted += 1
            }

            let measurement = Measurement(
                date: row.date,
                type: row.type,
                valueCm: row.valueCm,
                notes: row.notes
            )
            context.insert(measurement)

            do {
                try context.save()
            } catch {
                Log.data.error("CSV measurement import save failed", error)
                outcome.failed += 1
                continue
            }
            SyncHelper.mirrorRecord(measurement)

            if row.type == .waist {
                let sourceID = measurement.id
                let writeDate = measurement.date
                let writeValueCm = row.valueCm
                Task {
                    await HealthKitManager.mirror.saveWaistCircumference(
                        valueCm: writeValueCm,
                        date: writeDate,
                        sourceID: sourceID
                    )
                }
            }
        }
        Log.data.info("CSV measurement import: inserted=\(outcome.inserted) overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
        return outcome
    }

    /// Insert parsed scan rows. Conflict is per (day). Fires HealthKit
    /// mirror with the InBody payload. Imports are tagged `.imported`
    /// regardless of the row's original source so the UI can surface
    /// provenance.
    @discardableResult
    static func importScans(
        _ rows: [CSVScanRow],
        context: ModelContext,
        conflictStrategy: ConflictStrategy
    ) -> ImportOutcome {
        var outcome = ImportOutcome.empty
        for row in rows {
            let dayStart = Calendar.current.startOfDay(for: row.date)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            let descriptor = FetchDescriptor<Scan>(
                predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }
            )
            let existing = (try? context.fetch(descriptor)) ?? []

            if !existing.isEmpty {
                switch conflictStrategy {
                case .skip:
                    outcome.skipped += 1
                    continue
                case .overwrite:
                    for conflict in existing {
                        let staleID = conflict.id
                        context.delete(conflict)
                        Task { await HealthKitManager.mirror.deleteSamples(forSourceID: staleID) }
                    }
                    outcome.overwritten += 1
                }
            } else {
                outcome.inserted += 1
            }

            guard let data = try? JSONEncoder().encode(row.payload) else {
                Log.scan.error("CSV scan import: failed to encode payload")
                outcome.failed += 1
                continue
            }
            let scan = Scan(
                date: row.date,
                type: row.type,
                source: .imported,
                payload: data
            )
            context.insert(scan)

            do {
                try context.save()
            } catch {
                Log.data.error("CSV scan import save failed", error)
                outcome.failed += 1
                continue
            }
            SyncHelper.mirrorRecord(scan)

            let scanID = scan.id
            let scanDate = scan.date
            let hkPayload = row.payload
            Task {
                await HealthKitManager.mirror.deleteSamples(forSourceID: scanID)
                await HealthKitManager.mirror.saveScanMetrics(
                    payload: hkPayload,
                    date: scanDate,
                    sourceID: scanID
                )
            }
        }
        Log.data.info("CSV scan import: inserted=\(outcome.inserted) overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
        return outcome
    }

    // MARK: - Private

    /// Thrown from row parsers to attach a one-line reason to a `CSVParseIssue`.
    /// Kept private so callers go through `CSVParseIssue` instead.
    private struct ParseRowError: Error {
        let reason: String
        init(_ reason: String) { self.reason = reason }
    }

    private static func parse<Row: Equatable>(
        _ csv: String,
        expected: CSVFormat,
        rowParser: (Int, [String]) throws -> Row
    ) -> Result<CSVParseResult<Row>, CSVImportError> {
        let trimmed = csv.stripBOM().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyFile) }

        let lines = parseLines(trimmed)
        guard let headerLine = lines.first else { return .failure(.emptyFile) }

        let header = headerLine.joined(separator: ",").trimmingCharacters(in: .whitespaces)
        guard header == expected.expectedHeader else {
            return .failure(.missingOrMalformedHeader(expected: expected.expectedHeader, found: header))
        }

        var rows: [Row] = []
        var issues: [CSVParseIssue] = []
        for (index, columns) in lines.enumerated() where index > 0 {
            // Skip blank lines
            if columns.count == 1 && columns[0].trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            do {
                let row = try rowParser(index + 1, columns)
                rows.append(row)
            } catch let err as ParseRowError {
                issues.append(CSVParseIssue(line: index + 1, reason: err.reason))
            } catch {
                issues.append(CSVParseIssue(line: index + 1, reason: "\(error)"))
            }
        }
        return .success(CSVParseResult(rows: rows, issues: issues))
    }

    /// Splits a CSV blob into rows of columns, honouring RFC 4180 quoting
    /// (`""` → literal `"`, embedded commas and newlines inside quoted
    /// fields). Not a full RFC parser — just enough to round-trip what
    /// `CSVExporter.escapeCSV` produces.
    private static func parseLines(_ csv: String) -> [[String]] {
        // Normalise line endings up-front so the state machine only has to
        // think about "\n".
        let normalized = csv
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = normalized.makeIterator()

        while let ch = iterator.next() {
            if inQuotes {
                if ch == "\"" {
                    // Peek for escaped quote. No cheap peek on IndexingIterator,
                    // so we consume the next char and branch on it.
                    if let next = iterator.next() {
                        switch next {
                        case "\"":
                            field.append("\"")
                        case ",":
                            current.append(field)
                            field = ""
                            inQuotes = false
                        case "\n":
                            current.append(field)
                            field = ""
                            rows.append(current)
                            current = []
                            inQuotes = false
                        default:
                            // `"X` inside a quoted field is malformed per
                            // RFC but we're lenient — treat as literal.
                            field.append(next)
                            inQuotes = false
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case ",":
                    current.append(field)
                    field = ""
                case "\n":
                    current.append(field)
                    field = ""
                    rows.append(current)
                    current = []
                default:
                    field.append(ch)
                }
            }
        }
        // Flush any trailing field/row (no trailing newline).
        if !field.isEmpty || !current.isEmpty {
            current.append(field)
            rows.append(current)
        }
        return rows
    }
}
