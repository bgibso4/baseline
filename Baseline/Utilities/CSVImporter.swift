import Foundation
import SwiftData

// MARK: - Importer

enum CSVImporter {

    // MARK: Format dispatch

    /// Detects format from headers, parses rows accordingly, and returns
    /// a `ParsedImport` wrapper for the UI layer.
    static func parseAny(
        _ csv: String,
        defaultWeightUnit: String = "lb",
        defaultLengthUnit: String = "cm"
    ) -> Result<ParsedImport, CSVDispatchError> {
        guard let format = CSVFormat.detect(from: csv) else {
            return .failure(.unknownFormat)
        }
        switch format {
        case .weights:
            return parseWeights(csv, defaultUnit: defaultWeightUnit)
                .map(ParsedImport.weights)
                .mapError(CSVDispatchError.parseFailed)
        case .measurements:
            return parseMeasurements(csv, defaultUnit: defaultLengthUnit)
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

    // MARK: Weights

    /// Parses any weight CSV whose header exposes at least `date` and
    /// `weight` roles. Optional columns: time, unit, notes.
    /// Unit falls back to `defaultUnit` if the CSV doesn't identify one.
    static func parseWeights(
        _ csv: String,
        defaultUnit: String = "lb"
    ) -> Result<CSVParseResult<CSVWeightRow>, CSVImportError> {
        parseWithRoles(
            csv,
            required: [.date, .weight]
        ) { columns, map in
            guard let dateStr = map.value(columns, for: .date) else {
                throw ParseRowError("missing date")
            }
            let timeStr = map.value(columns, for: .time)
            guard let date = FlexibleDateParser.parse(date: dateStr, time: timeStr) else {
                let extra = timeStr.map { " + '\($0)'" } ?? ""
                throw ParseRowError("couldn't parse date '\(dateStr)'\(extra)")
            }

            guard let weightStr = map.value(columns, for: .weight),
                  let weight = Double(weightStr),
                  weight > 0 else {
                throw ParseRowError("invalid weight: \(map.value(columns, for: .weight) ?? "<missing>")")
            }

            guard let unit = WeightUnitResolver.resolve(
                explicit: map.value(columns, for: .weightUnit),
                headerHint: map.hint(for: .weight),
                default: defaultUnit
            ) else {
                throw ParseRowError("unrecognised weight unit")
            }

            let notes = map.value(columns, for: .notes)
            return CSVWeightRow(date: date, weight: weight, unit: unit, notes: notes)
        }
    }

    // MARK: Measurements

    /// Parses any measurement CSV whose header exposes `date`,
    /// measurement type, and a measurement value. Values in inches are
    /// converted to cm on ingest; cm passes through unchanged.
    static func parseMeasurements(
        _ csv: String,
        defaultUnit: String = "cm"
    ) -> Result<CSVParseResult<CSVMeasurementRow>, CSVImportError> {
        // Measurement type can live under either `measurementType` (if
        // that's unambiguous) or `scanType` (if the header just says
        // `type`). Require one or the other.
        let typeRoleResolver: (HeaderMap) -> ColumnRole? = { map in
            if map.has(.measurementType) { return .measurementType }
            if map.has(.scanType) { return .scanType }
            return nil
        }

        return parseWithRoles(
            csv,
            required: [.date, .measurementValue],
            additionalGuard: { map in
                typeRoleResolver(map) == nil
                    ? [ColumnRole.measurementType]
                    : []
            },
            rowParser: { columns, map in
                guard let dateStr = map.value(columns, for: .date) else {
                    throw ParseRowError("missing date")
                }
                let timeStr = map.value(columns, for: .time)
                guard let date = FlexibleDateParser.parse(date: dateStr, time: timeStr) else {
                    throw ParseRowError("couldn't parse date '\(dateStr)'")
                }

                guard let typeRole = typeRoleResolver(map),
                      let typeRaw = map.value(columns, for: typeRole) else {
                    throw ParseRowError("missing measurement type")
                }
                guard let type = MeasurementType(rawValue: typeRaw) else {
                    throw ParseRowError("unknown measurement type: \(typeRaw)")
                }

                guard let valueStr = map.value(columns, for: .measurementValue),
                      let value = Double(valueStr),
                      value > 0 else {
                    let badVal = map.value(columns, for: .measurementValue) ?? "<missing>"
                    throw ParseRowError("invalid measurement value: \(badVal)")
                }

                guard let unit = LengthUnitResolver.resolveUnit(
                    explicit: nil,
                    headerHint: map.hint(for: .measurementValue),
                    default: defaultUnit
                ) else {
                    throw ParseRowError("unrecognised length unit")
                }
                let valueCm = LengthUnitResolver.toCentimeters(value, unit: unit)

                let notes = map.value(columns, for: .notes)
                return CSVMeasurementRow(date: date, type: type, valueCm: valueCm, notes: notes)
            }
        )
    }

    // MARK: Scans

    /// Parses Baseline's InBody scan CSV. All 7 core metrics plus date
    /// are required; scan type and source are optional and default to
    /// `.inBody` / `.imported` when absent.
    static func parseScans(_ csv: String) -> Result<CSVParseResult<CSVScanRow>, CSVImportError> {
        let scanCoreFields: Set<ColumnRole> = [
            .scanWeightKg, .scanSMM, .scanBFM, .scanPBF, .scanTBW, .scanBMI, .scanBMR
        ]

        return parseWithRoles(
            csv,
            required: Set([ColumnRole.date]).union(scanCoreFields)
        ) { columns, map in
            guard let dateStr = map.value(columns, for: .date) else {
                throw ParseRowError("missing date")
            }
            let timeStr = map.value(columns, for: .time)
            guard let date = FlexibleDateParser.parse(date: dateStr, time: timeStr) else {
                throw ParseRowError("couldn't parse date '\(dateStr)'")
            }

            // Scan type/source: if the column is present, require a valid
            // value; if absent, default to the sensible baseline.
            let type: ScanType
            if let typeRaw = map.value(columns, for: .scanType) {
                guard let parsed = ScanType(rawValue: typeRaw) else {
                    throw ParseRowError("unknown scan type: \(typeRaw)")
                }
                type = parsed
            } else {
                type = .inBody
            }

            let source: ScanSource
            if let sourceRaw = map.value(columns, for: .scanSource) {
                guard let parsed = ScanSource(rawValue: sourceRaw) else {
                    throw ParseRowError("unknown scan source: \(sourceRaw)")
                }
                source = parsed
            } else {
                source = .imported
            }

            func double(_ role: ColumnRole, minAllowed: Double = 0) throws -> Double {
                guard let raw = map.value(columns, for: role),
                      let value = Double(raw),
                      value >= minAllowed else {
                    throw ParseRowError("invalid \(role.rawValue): \(map.value(columns, for: role) ?? "<missing>")")
                }
                return value
            }

            let payload = InBodyPayload(
                weightKg: try double(.scanWeightKg, minAllowed: 0.0001),
                skeletalMuscleMassKg: try double(.scanSMM),
                bodyFatMassKg: try double(.scanBFM),
                bodyFatPct: try double(.scanPBF),
                totalBodyWaterL: try double(.scanTBW),
                bmi: try double(.scanBMI, minAllowed: 0.0001),
                basalMetabolicRate: try double(.scanBMR)
            )
            return CSVScanRow(date: date, type: type, source: source, payload: payload)
        }
    }

    // MARK: Persistence

    /// Insert parsed weight rows into the context. Fires HealthKit mirror
    /// tasks for each persisted entry so the UUID-tagged samples match the
    /// single-entry save path. Returns per-row outcome counts.
    @discardableResult
    static func importWeights(
        _ rows: [CSVWeightRow],
        context: ModelContext,
        conflictStrategy: ConflictStrategy
    ) -> ImportOutcome {
        Log.data.info("CSV importWeights: \(rows.count) rows, strategy=\(String(describing: conflictStrategy))")
        var outcome = ImportOutcome.empty
        for (index, row) in rows.enumerated() {
            let dayStart = Calendar.current.startOfDay(for: row.date)
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
                Log.data.error("CSV importWeights: couldn't compute day bounds for row \(index)")
                outcome.failed += 1
                continue
            }
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
        Log.data.info("CSV weight import: inserted=\(outcome.inserted)" +
            " overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
        return outcome
    }

    @discardableResult
    static func importMeasurements(
        _ rows: [CSVMeasurementRow],
        context: ModelContext,
        conflictStrategy: ConflictStrategy
    ) -> ImportOutcome {
        Log.data.info("CSV importMeasurements: \(rows.count) rows, strategy=\(String(describing: conflictStrategy))")
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
        Log.data.info("CSV measurement import: inserted=\(outcome.inserted)" +
            " overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
        return outcome
    }

    @discardableResult
    static func importScans(
        _ rows: [CSVScanRow],
        context: ModelContext,
        conflictStrategy: ConflictStrategy
    ) -> ImportOutcome {
        Log.data.info("CSV importScans: \(rows.count) rows, strategy=\(String(describing: conflictStrategy))")
        var outcome = ImportOutcome.empty
        for (index, row) in rows.enumerated() {
            let dayStart = Calendar.current.startOfDay(for: row.date)
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
                Log.data.error("CSV importScans: couldn't compute day bounds for row \(index)")
                outcome.failed += 1
                continue
            }
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
        Log.data.info("CSV scan import: inserted=\(outcome.inserted)" +
            " overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
        return outcome
    }

    // MARK: - Private

    /// Thrown from row parsers to attach a one-line reason to a `CSVParseIssue`.
    struct ParseRowError: Error {
        let reason: String
        init(_ reason: String) { self.reason = reason }
    }

    /// Generic parse loop. Builds a `HeaderMap`, checks that every
    /// required role is present (plus any additional guard roles the
    /// caller computes from the map), then invokes the row parser for
    /// each data line. Malformed rows become `CSVParseIssue`s; clean
    /// rows accumulate in `rows`.
    private static func parseWithRoles<Row: Equatable>(
        _ csv: String,
        required: Set<ColumnRole>,
        additionalGuard: (HeaderMap) -> [ColumnRole] = { _ in [] },
        rowParser: ([String], HeaderMap) throws -> Row
    ) -> Result<CSVParseResult<Row>, CSVImportError> {
        let trimmed = csv.stripBOM().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyFile) }

        let lines = parseLines(trimmed)
        guard let headers = lines.first else { return .failure(.emptyFile) }

        let map = HeaderMap.build(from: headers)

        var missing = map.missing(required).map(\.rawValue)
        missing.append(contentsOf: additionalGuard(map).map(\.rawValue))
        guard missing.isEmpty else {
            return .failure(.missingRequiredColumns(missing))
        }

        var rows: [Row] = []
        var issues: [CSVParseIssue] = []
        for (index, columns) in lines.enumerated() where index > 0 {
            if columns.count == 1 && columns[0].trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            do {
                let row = try rowParser(columns, map)
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
    /// fields). Exposed internally (`_` prefix) so `CSVFormat.detect`
    /// can share the same quoting logic for its first-line peek.
    static func parseLines(_ csv: String) -> [[String]] {
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
        if !field.isEmpty || !current.isEmpty {
            current.append(field)
            rows.append(current)
        }
        return rows
    }
}
