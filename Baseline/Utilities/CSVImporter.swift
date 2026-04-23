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
    /// Header doesn't supply the columns the target format needs. Each
    /// string is the semantic name of a missing column (e.g. "date",
    /// "weight"). Callers surface these to the user verbatim.
    case missingRequiredColumns([String])
}

/// Semantic identity of the parsed rows. Determined from which column
/// roles are present in the header — no more exact header-string match.
enum CSVFormat: String {
    case weights
    case measurements
    case scans
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

// MARK: - Column roles
//
// The semantic dimensions a CSV row can carry, independent of what the
// source spreadsheet happens to call them. Parsers extract data by role,
// not by column index or header string — so a header of `Weight (lb)` and
// one of `lb` resolve to the same thing.

/// Semantic role of a single CSV column.
enum ColumnRole: String, Hashable, CaseIterable {
    // Shared across all formats
    case date
    case time
    case notes

    // Weight entries
    case weight
    case weightUnit

    // Tape measurements
    case measurementType
    case measurementValue

    // InBody scans
    case scanType
    case scanSource
    case scanWeightKg
    case scanSMM
    case scanBFM
    case scanPBF
    case scanTBW
    case scanBMI
    case scanBMR
}

/// Registry of acceptable header names for each role. Matching is
/// case-insensitive, trims whitespace, and ignores parenthesized hints
/// (which are captured separately for unit resolution).
///
/// **Extension point:** to accept a new synonym for an existing role,
/// add it to the set. To introduce a new role, add a `ColumnRole` case
/// and a matching entry here — the parsers pick it up via `HeaderMap`
/// without any orchestration change.
enum ColumnSynonyms {
    static let registry: [ColumnRole: Set<String>] = [
        .date: ["date", "day", "timestamp", "datetime"],
        .time: ["time", "time of day", "clock"],
        .notes: ["notes", "note", "comment", "comments", "memo"],

        .weight: ["weight", "mass", "lb", "lbs", "kg", "kgs", "pounds", "kilograms"],
        .weightUnit: ["unit", "units"],

        .measurementType: ["type", "measurement", "part", "site"],
        .measurementValue: ["value", "valuecm", "valuein", "measurement value", "cm", "in", "inches", "centimeters"],

        .scanType: ["type", "scan type"],
        .scanSource: ["source", "scan source"],
        .scanWeightKg: ["weightkg", "weight_kg"],
        .scanSMM: ["skeletalmusclemasskg", "skeletal_muscle_mass_kg", "smm"],
        .scanBFM: ["bodyfatmasskg", "body_fat_mass_kg", "bfm"],
        .scanPBF: ["bodyfatpct", "body_fat_pct", "pbf"],
        .scanTBW: ["totalbodywaterl", "total_body_water_l", "tbw"],
        .scanBMI: ["bmi"],
        .scanBMR: ["basalmetabolicrate", "basal_metabolic_rate", "bmr"],
    ]

    /// Returns every role whose synonym set contains this normalised
    /// header. Multiple roles can match (e.g. `type` matches both
    /// `.measurementType` and `.scanType`); format detection later
    /// disambiguates based on which required-column-sets are satisfied.
    static func roles(forNormalized header: String) -> Set<ColumnRole> {
        var matches: Set<ColumnRole> = []
        for (role, synonyms) in registry where synonyms.contains(header) {
            matches.insert(role)
        }
        return matches
    }
}

// MARK: - Header parsing

/// One header cell's raw form broken into the parts each consumer needs:
/// the synonym-match key (`normalized`) and the optional unit hint
/// extracted from any parenthesized suffix (`"Weight (lb)"` → `"lb"`).
struct NormalizedHeader: Equatable {
    let raw: String
    let normalized: String
    let parentheticalHint: String?

    init(_ raw: String) {
        self.raw = raw
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if let openIdx = trimmed.firstIndex(of: "("),
           let closeIdx = trimmed.firstIndex(of: ")"),
           openIdx < closeIdx {
            let hint = trimmed[trimmed.index(after: openIdx)..<closeIdx]
            let base = trimmed[..<openIdx]
            self.parentheticalHint = hint.trimmingCharacters(in: .whitespaces).lowercased()
            self.normalized = base.trimmingCharacters(in: .whitespaces).lowercased()
        } else {
            self.parentheticalHint = nil
            self.normalized = trimmed.lowercased()
        }
    }
}

/// Maps semantic roles to column indexes. Built once per header row and
/// reused by the per-row parsers.
///
/// Ambiguity handling: if a header matches multiple roles (e.g. `type`
/// → `.measurementType` and `.scanType`), both entries point to the
/// same column index. Format detection resolves which one is load-bearing.
struct HeaderMap {
    /// Headers as they appeared in the file (for error messages).
    let rawHeaders: [String]
    /// Role → column index, first match wins.
    let roleIndex: [ColumnRole: Int]
    /// Role → parenthesized hint captured from that column's header,
    /// if any (e.g. `"lb"` from `Weight (lb)`).
    let roleHint: [ColumnRole: String]

    static func build(from headers: [String]) -> HeaderMap {
        var roleIndex: [ColumnRole: Int] = [:]
        var roleHint: [ColumnRole: String] = [:]

        for (columnIndex, raw) in headers.enumerated() {
            let norm = NormalizedHeader(raw)
            for role in ColumnSynonyms.roles(forNormalized: norm.normalized) {
                if roleIndex[role] == nil {
                    roleIndex[role] = columnIndex
                    if let hint = norm.parentheticalHint {
                        roleHint[role] = hint
                    }
                }
            }
        }

        return HeaderMap(
            rawHeaders: headers,
            roleIndex: roleIndex,
            roleHint: roleHint
        )
    }

    func has(_ role: ColumnRole) -> Bool { roleIndex[role] != nil }

    func hasAll(_ roles: Set<ColumnRole>) -> Bool {
        roles.allSatisfy { has($0) }
    }

    func hasAny(_ roles: Set<ColumnRole>) -> Bool {
        roles.contains { has($0) }
    }

    /// Which of the given roles are missing. Used to build user-facing
    /// error messages when required columns aren't satisfied.
    func missing(_ roles: Set<ColumnRole>) -> [ColumnRole] {
        roles.filter { !has($0) }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Raw value at the column matching `role`, trimmed. Returns nil if
    /// the role is unmapped, the row is short, or the cell is blank.
    func value(_ columns: [String], for role: ColumnRole) -> String? {
        guard let index = roleIndex[role], index < columns.count else { return nil }
        let v = columns[index].trimmingCharacters(in: .whitespaces)
        return v.isEmpty ? nil : v
    }

    /// Parenthesized hint captured from `role`'s header cell, if any.
    func hint(for role: ColumnRole) -> String? { roleHint[role] }
}

// MARK: - Date parsing

/// Tries a fixed list of format strings in order until one matches. When
/// a separate time column is also provided, each base format is tried
/// alongside `HH:mm:ss` and `HH:mm` variants.
///
/// **Extension point:** to accept a new date format, add its
/// `DateFormatter.dateFormat` string to `baseFormats`. Preformatted
/// `DateFormatter` instances are cached at load time (POSIX locale,
/// `twoDigitStartDate` anchored to year 2000) so parsing 10,000+ rows
/// doesn't allocate a formatter per row.
enum FlexibleDateParser {
    /// Format strings for the date portion. Ordered so that 2-digit-year
    /// variants are tried BEFORE 4-digit — otherwise DateFormatter in
    /// lenient mode will parse "5/26/21" as the year 0021. We also set
    /// `isLenient = false` below to make format boundaries strict.
    private static let baseFormats: [String] = [
        // ISO 8601 variants
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",

        // Slash-separated — 2-digit year first to anchor into the 2000s
        // before the 4-digit patterns have a chance to match loosely.
        "MM/dd/yy",
        "M/d/yy",
        "MM/dd/yyyy",
        "M/d/yyyy",

        // Other
        "yyyy/MM/dd",
        "dd-MM-yyyy",
    ]

    /// Pre-built formatters covering each base format plus two common
    /// time-column append variants. Order matches `baseFormats`.
    private static let formatters: [DateFormatter] = {
        let anchorYear2000: Date? = {
            var cal = Calendar(identifier: .gregorian)
            cal.locale = Locale(identifier: "en_US_POSIX")
            return cal.date(from: DateComponents(year: 2000))
        }()

        return baseFormats.flatMap { base -> [DateFormatter] in
            [base, "\(base) HH:mm:ss", "\(base) HH:mm"].map { pattern in
                let f = DateFormatter()
                f.calendar = Calendar(identifier: .gregorian)
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                f.dateFormat = pattern
                f.twoDigitStartDate = anchorYear2000
                f.isLenient = false
                return f
            }
        }
    }()

    /// Parses a date string (optionally combined with a separate time
    /// column) against every registered format, returning the first
    /// successful match. Returns nil if nothing parses.
    static func parse(date dateString: String, time timeString: String? = nil) -> Date? {
        let dateTrim = dateString.trimmingCharacters(in: .whitespaces)
        guard !dateTrim.isEmpty else { return nil }

        let combined: String
        if let timeString, !timeString.trimmingCharacters(in: .whitespaces).isEmpty {
            combined = "\(dateTrim) \(timeString.trimmingCharacters(in: .whitespaces))"
        } else {
            combined = dateTrim
        }

        for formatter in formatters {
            if let d = formatter.date(from: combined) { return d }
        }
        return nil
    }
}

// MARK: - Unit resolution

/// Resolves the canonical unit for a weight row from, in priority order:
/// 1. An explicit unit column cell value
/// 2. A parenthesized hint in the weight column's header (`Weight (kg)`)
/// 3. The supplied default (usually the user's app-wide preference)
///
/// Returns nil if no source yields a recognisable unit — callers decide
/// whether to fall back further or reject the row.
enum WeightUnitResolver {
    static func resolve(
        explicit: String?,
        headerHint: String?,
        default defaultUnit: String
    ) -> String? {
        if let normalized = normalize(explicit) { return normalized }
        if let normalized = normalize(headerHint) { return normalized }
        if let normalized = normalize(defaultUnit) { return normalized }
        return nil
    }

    private static func normalize(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        switch raw.lowercased() {
        case "lb", "lbs", "pound", "pounds": return "lb"
        case "kg", "kgs", "kilogram", "kilograms": return "kg"
        default: return nil
        }
    }
}

/// Resolves the canonical length unit for a measurement row and converts
/// raw numeric values to centimetres (Baseline's storage unit). Falls
/// back to the supplied default if neither the column nor the header
/// identifies a unit.
enum LengthUnitResolver {
    static func resolveUnit(
        explicit: String?,
        headerHint: String?,
        default defaultUnit: String
    ) -> String? {
        if let n = normalize(explicit) { return n }
        if let n = normalize(headerHint) { return n }
        return normalize(defaultUnit)
    }

    static func toCentimeters(_ value: Double, unit: String) -> Double {
        switch unit {
        case "cm": return value
        case "in": return value * 2.54
        default: return value
        }
    }

    private static func normalize(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        switch raw.lowercased() {
        case "cm", "centimeter", "centimeters", "centimetres": return "cm"
        case "in", "inch", "inches": return "in"
        default: return nil
        }
    }
}

// MARK: - Format detection

extension CSVFormat {
    /// Top-level entry point: strip BOM + normalise line endings, extract
    /// the header, and hand it to `detect(from: HeaderMap)`.
    static func detect(from csv: String) -> CSVFormat? {
        let cleaned = csv.stripBOM()
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let firstLine = cleaned.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""

        // Parse the first line through the full quoting-aware parser so
        // quoted headers (`"Weight (lb)"`) resolve the same way values do.
        let lines = CSVImporter._parseLines(firstLine)
        guard let headers = lines.first else { return nil }
        return detect(from: HeaderMap.build(from: headers))
    }

    /// Role-based detection. Most-specific format wins so a scan CSV
    /// (which includes a weight column) isn't misclassified as weights.
    static func detect(from headerMap: HeaderMap) -> CSVFormat? {
        let scanCoreFields: Set<ColumnRole> = [
            .scanWeightKg, .scanSMM, .scanBFM, .scanPBF, .scanTBW, .scanBMI, .scanBMR,
        ]
        if headerMap.has(.date) && headerMap.hasAll(scanCoreFields) {
            return .scans
        }

        let hasMeasurementType = headerMap.hasAny([.measurementType, .scanType])
        if headerMap.has(.date) && hasMeasurementType && headerMap.has(.measurementValue) {
            return .measurements
        }

        if headerMap.has(.date) && headerMap.has(.weight) {
            return .weights
        }

        return nil
    }
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
            }
        ) { columns, map in
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
                throw ParseRowError("invalid measurement value: \(map.value(columns, for: .measurementValue) ?? "<missing>")")
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
    }

    // MARK: Scans

    /// Parses Baseline's InBody scan CSV. All 7 core metrics plus date
    /// are required; scan type and source are optional and default to
    /// `.inBody` / `.imported` when absent.
    static func parseScans(_ csv: String) -> Result<CSVParseResult<CSVScanRow>, CSVImportError> {
        let scanCoreFields: Set<ColumnRole> = [
            .scanWeightKg, .scanSMM, .scanBFM, .scanPBF, .scanTBW, .scanBMI, .scanBMR,
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
        Log.data.info("CSV weight import: inserted=\(outcome.inserted) overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
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
        Log.data.info("CSV measurement import: inserted=\(outcome.inserted) overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
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
        Log.data.info("CSV scan import: inserted=\(outcome.inserted) overwritten=\(outcome.overwritten) skipped=\(outcome.skipped) failed=\(outcome.failed)")
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

        let lines = _parseLines(trimmed)
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
    static func _parseLines(_ csv: String) -> [[String]] {
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
