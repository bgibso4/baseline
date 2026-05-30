import Foundation

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
        let lines = CSVImporter.parseLines(firstLine)
        guard let headers = lines.first else { return nil }
        return detect(from: HeaderMap.build(from: headers))
    }

    /// Role-based detection. Most-specific format wins so a scan CSV
    /// (which includes a weight column) isn't misclassified as weights.
    static func detect(from headerMap: HeaderMap) -> CSVFormat? {
        let scanCoreFields: Set<ColumnRole> = [
            .scanWeightKg, .scanSMM, .scanBFM, .scanPBF, .scanTBW, .scanBMI, .scanBMR
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
