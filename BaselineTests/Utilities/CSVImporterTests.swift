import XCTest
import SwiftData
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// Covers the CSV import path end-to-end:
/// 1. Pure parsing (good rows, bad rows, header checks, quoting).
/// 2. Persistence (skip vs. overwrite, HK mirror invocation via spy).
/// 3. Round-trip: export → parse → data equality.
final class CSVImporterTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var spy: SpyHealthKitMirror!
    var realMirror: HealthMirroring!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, Scan.self, Measurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        realMirror = HealthKitManager.mirror
        spy = SpyHealthKitMirror()
        HealthKitManager.mirror = spy
    }

    override func tearDown() async throws {
        // Drain any VM-spawned tasks before restoring the real mirror so
        // they don't bleed into adjacent tests.
        try? await Task.sleep(nanoseconds: 150_000_000)
        HealthKitManager.mirror = realMirror
        container = nil
        context = nil
        spy = nil
        try await super.tearDown()
    }

    // MARK: - Format detection

    func testDetectFormat_weights() {
        let csv = "date,weight,unit,notes\n2026-04-15T00:00:00.000Z,185.4,lb,"
        XCTAssertEqual(CSVFormat.detect(from: csv), .weights)
    }

    func testDetectFormat_measurements() {
        let csv = "date,type,valueCm,notes\n2026-04-15T00:00:00.000Z,waist,84.0,"
        XCTAssertEqual(CSVFormat.detect(from: csv), .measurements)
    }

    func testDetectFormat_scans() {
        let csv = "date,type,source,weightKg,skeletalMuscleMassKg,bodyFatMassKg,bodyFatPct,totalBodyWaterL,bmi,basalMetabolicRate\n"
        XCTAssertEqual(CSVFormat.detect(from: csv), .scans)
    }

    func testDetectFormat_unknown() {
        XCTAssertNil(CSVFormat.detect(from: "date,foo,bar\n"))
    }

    // MARK: - Weight parsing

    func testParseWeights_validRows() {
        let csv = """
        date,weight,unit,notes
        2026-04-15T00:00:00.000Z,185.4,lb,morning
        2026-04-16T00:00:00.000Z,185.1,lb,
        """
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 2)
        XCTAssertEqual(parsed.issues.count, 0)
        XCTAssertEqual(parsed.rows[0].weight, 185.4)
        XCTAssertEqual(parsed.rows[0].unit, "lb")
        XCTAssertEqual(parsed.rows[0].notes, "morning")
        XCTAssertNil(parsed.rows[1].notes)
    }

    func testParseWeights_invalidRowsKeptAsIssues() {
        // Unit "stone" now falls through to the defaultUnit because the
        // resolver silently ignores unrecognised unit names — so the row
        // succeeds as lb. Bad date/weight rows still become issues.
        let csv = """
        date,weight,unit,notes
        2026-04-15T00:00:00.000Z,185.4,lb,ok
        not-a-date,185.4,lb,bad date
        2026-04-17T00:00:00.000Z,heavy,lb,bad weight
        2026-04-19T00:00:00.000Z,179.0,kg,good kg
        """
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 2, "only 2 valid rows")
        XCTAssertEqual(parsed.issues.count, 2)
        XCTAssertTrue(parsed.issues[0].reason.contains("couldn't parse date"))
        XCTAssertTrue(parsed.issues[1].reason.contains("invalid weight"))
    }

    func testParseWeights_quotedNotesWithComma() {
        // CSV escapes commas by wrapping in quotes — verify round-trip.
        let csv = """
        date,weight,unit,notes
        2026-04-15T00:00:00.000Z,185.4,lb,"first, half"
        """
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.first?.notes, "first, half")
    }

    func testParseWeights_emptyFile_returnsError() {
        let result = CSVImporter.parseWeights("")
        guard case .failure(let err) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(err, .emptyFile)
    }

    func testParseWeights_missingRequiredColumns_returnsError() {
        // Header has no weight column → the importer refuses and reports
        // which required role is missing.
        let csv = "date,unit,notes\n"
        let result = CSVImporter.parseWeights(csv)
        guard case .failure(let err) = result else { return XCTFail("expected failure") }
        if case .missingRequiredColumns(let missing) = err {
            XCTAssertTrue(missing.contains("weight"),
                          "expected 'weight' in missing list, got \(missing)")
        } else {
            XCTFail("expected missingRequiredColumns, got \(err)")
        }
    }

    func testParseWeights_acceptsTimestampSynonym() {
        // `timestamp` is a registered synonym for `date` — file should parse.
        let csv = """
        timestamp,weight,unit,notes
        2026-04-15T00:00:00.000Z,185.4,lb,
        """
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 1)
    }

    func testParseWeights_headerOnly_returnsEmptyRows() {
        let csv = "date,weight,unit,notes"
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 0)
    }

    // MARK: - Measurement parsing

    func testParseMeasurements_validRows() {
        let csv = """
        date,type,valueCm,notes
        2026-04-15T00:00:00.000Z,waist,84.5,
        2026-04-15T00:00:00.000Z,armLeft,32.0,left bicep
        """
        let result = CSVImporter.parseMeasurements(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 2)
        XCTAssertEqual(parsed.rows[0].type, .waist)
        XCTAssertEqual(parsed.rows[1].type, .armLeft)
        XCTAssertEqual(parsed.rows[1].notes, "left bicep")
    }

    func testParseMeasurements_unknownType_becomesIssue() {
        let csv = """
        date,type,valueCm,notes
        2026-04-15T00:00:00.000Z,forearm,30.0,
        """
        let result = CSVImporter.parseMeasurements(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 0)
        XCTAssertEqual(parsed.issues.count, 1)
        XCTAssertTrue(parsed.issues[0].reason.contains("unknown measurement type"))
    }

    // MARK: - Scan parsing

    func testParseScans_validRow() {
        let csv = """
        date,type,source,weightKg,skeletalMuscleMassKg,bodyFatMassKg,bodyFatPct,totalBodyWaterL,bmi,basalMetabolicRate
        2026-04-15T00:00:00.000Z,inBody,manual,89.5,38.2,15.1,16.9,54.3,25.8,1850.0
        """
        let result = CSVImporter.parseScans(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 1)
        let row = parsed.rows[0]
        XCTAssertEqual(row.type, .inBody)
        XCTAssertEqual(row.source, .manual)
        XCTAssertEqual(row.payload.weightKg, 89.5)
        XCTAssertEqual(row.payload.basalMetabolicRate, 1850)
    }

    func testParseScans_unknownSource_becomesIssue() {
        let csv = """
        date,type,source,weightKg,skeletalMuscleMassKg,bodyFatMassKg,bodyFatPct,totalBodyWaterL,bmi,basalMetabolicRate
        2026-04-15T00:00:00.000Z,inBody,gremlin,89.5,38.2,15.1,16.9,54.3,25.8,1850.0
        """
        let result = CSVImporter.parseScans(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.rows.count, 0)
        XCTAssertEqual(parsed.issues.first?.reason.contains("unknown scan source"), true)
    }

    // MARK: - Round-trip (export → parse → data equality)

    func testRoundTrip_weights() {
        let dateA = Calendar.current.startOfDay(for: Date())
        let dateB = Calendar.current.date(byAdding: .day, value: -1, to: dateA)!
        context.insert(WeightEntry(weight: 185.4, unit: "lb", date: dateA, notes: "morning"))
        context.insert(WeightEntry(weight: 186.0, unit: "lb", date: dateB, notes: nil))
        try! context.save()

        let csv = CSVExporter.exportWeights(context: context)
        let parsed = try! CSVImporter.parseWeights(csv).get()

        XCTAssertEqual(parsed.rows.count, 2)
        XCTAssertEqual(parsed.issues.count, 0)
        let weights = parsed.rows.map { $0.weight }.sorted()
        XCTAssertEqual(weights, [185.4, 186.0])
    }

    func testRoundTrip_measurements() {
        let today = Calendar.current.startOfDay(for: Date())
        context.insert(Measurement(date: today, type: .waist, valueCm: 84.5))
        context.insert(Measurement(date: today, type: .armLeft, valueCm: 32.0, notes: "left, bicep"))
        try! context.save()

        let csv = CSVExporter.exportMeasurements(context: context)
        let parsed = try! CSVImporter.parseMeasurements(csv).get()

        XCTAssertEqual(parsed.rows.count, 2)
        let rowsByType = Dictionary(uniqueKeysWithValues: parsed.rows.map { ($0.type, $0) })
        XCTAssertEqual(rowsByType[.waist]?.valueCm, 84.5)
        XCTAssertEqual(rowsByType[.armLeft]?.notes, "left, bicep")
    }

    func testRoundTrip_scans() {
        let payload = InBodyPayload(
            weightKg: 89.5,
            skeletalMuscleMassKg: 38.2,
            bodyFatMassKg: 15.1,
            bodyFatPct: 16.9,
            totalBodyWaterL: 54.3,
            bmi: 25.8,
            basalMetabolicRate: 1850
        )
        let data = try! JSONEncoder().encode(payload)
        context.insert(Scan(date: Date(), type: .inBody, source: .manual, payload: data))
        try! context.save()

        let csv = CSVExporter.exportScans(context: context)
        let parsed = try! CSVImporter.parseScans(csv).get()
        XCTAssertEqual(parsed.rows.count, 1)
        XCTAssertEqual(parsed.rows[0].payload.weightKg, 89.5)
        XCTAssertEqual(parsed.rows[0].payload.bodyFatPct, 16.9)
        XCTAssertEqual(parsed.rows[0].payload.basalMetabolicRate, 1850)
    }

    // MARK: - Import persistence (weights)

    func testImportWeights_insertsAllForEmptyStore() async {
        let dateA = Calendar.current.startOfDay(for: Date())
        let dateB = Calendar.current.date(byAdding: .day, value: -1, to: dateA)!
        let rows = [
            CSVWeightRow(date: dateA, weight: 185.4, unit: "lb", notes: "morning"),
            CSVWeightRow(date: dateB, weight: 186.0, unit: "lb", notes: nil),
        ]

        let outcome = CSVImporter.importWeights(rows, context: context, conflictStrategy: .skip)

        XCTAssertEqual(outcome.inserted, 2)
        XCTAssertEqual(outcome.skipped, 0)
        XCTAssertEqual(outcome.overwritten, 0)

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 2)

        await spy.waitForCalls(2)
        let saveCalls = await spy.calls.filter {
            if case .saveWeight = $0 { return true } else { return false }
        }
        XCTAssertEqual(saveCalls.count, 2, "each import row should fire a saveWeight mirror call")
    }

    func testImportWeights_skipStrategy_keepsExisting() async {
        let today = Calendar.current.startOfDay(for: Date())
        let existing = WeightEntry(weight: 200.0, unit: "lb", date: today)
        context.insert(existing)
        try! context.save()
        let existingID = existing.id

        // Reset spy after setup so we only see import-time calls.
        await spy.reset()

        let rows = [CSVWeightRow(date: today, weight: 185.4, unit: "lb", notes: nil)]
        let outcome = CSVImporter.importWeights(rows, context: context, conflictStrategy: .skip)

        XCTAssertEqual(outcome.skipped, 1)
        XCTAssertEqual(outcome.inserted, 0)

        let entries = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, existingID)
        XCTAssertEqual(entries.first?.weight, 200.0)

        // No HK calls should fire on skip.
        try? await Task.sleep(nanoseconds: 100_000_000)
        let hkCalls = await spy.calls
        XCTAssertEqual(hkCalls.count, 0, "skip strategy must not invoke HK mirror")
    }

    func testImportWeights_overwriteStrategy_replacesExistingAndDeletesHKSamples() async {
        let today = Calendar.current.startOfDay(for: Date())
        let existing = WeightEntry(weight: 200.0, unit: "lb", date: today)
        context.insert(existing)
        try! context.save()
        let existingID = existing.id

        await spy.reset()

        let rows = [CSVWeightRow(date: today, weight: 185.4, unit: "lb", notes: "fresh")]
        let outcome = CSVImporter.importWeights(rows, context: context, conflictStrategy: .overwrite)

        XCTAssertEqual(outcome.overwritten, 1)

        let entries = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, 185.4)
        XCTAssertNotEqual(entries.first?.id, existingID, "a fresh WeightEntry is created — existing one is deleted")

        await spy.waitForCalls(3)
        let calls = await spy.calls
        // Expected sequence: delete(existingID), delete(newID), saveWeight(newID)
        XCTAssertTrue(calls.contains(.delete(sourceID: existingID)),
                      "stale HK samples for overwritten entry should be deleted by UUID")
        XCTAssertEqual(calls.filter { if case .saveWeight = $0 { return true } else { return false } }.count, 1)
    }

    // MARK: - Import persistence (measurements)

    func testImportMeasurements_waistFiresHKMirror() async {
        let today = Calendar.current.startOfDay(for: Date())
        let rows = [
            CSVMeasurementRow(date: today, type: .waist, valueCm: 84.5, notes: nil),
            CSVMeasurementRow(date: today, type: .armLeft, valueCm: 32.0, notes: nil),
        ]
        let outcome = CSVImporter.importMeasurements(rows, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 2)

        await spy.waitForCalls(1)
        let calls = await spy.calls
        let waistCalls = calls.filter {
            if case .saveWaist = $0 { return true } else { return false }
        }
        XCTAssertEqual(waistCalls.count, 1, "only waist should fire HK mirror")
    }

    func testImportMeasurements_overwriteReplacesSameTypeDay() async {
        let today = Calendar.current.startOfDay(for: Date())
        let existing = Measurement(date: today, type: .waist, valueCm: 88.0)
        context.insert(existing)
        try! context.save()
        let existingID = existing.id

        await spy.reset()

        let rows = [CSVMeasurementRow(date: today, type: .waist, valueCm: 84.5, notes: nil)]
        let outcome = CSVImporter.importMeasurements(rows, context: context, conflictStrategy: .overwrite)
        XCTAssertEqual(outcome.overwritten, 1)

        let entries = try! context.fetch(FetchDescriptor<Measurement>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.valueCm, 84.5)
        XCTAssertNotEqual(entries.first?.id, existingID)

        await spy.waitForCalls(2)
        let calls = await spy.calls
        XCTAssertTrue(calls.contains(.delete(sourceID: existingID)))
    }

    // MARK: - Import persistence (scans)

    func testImportScans_insertsAndFiresMirror() async {
        let payload = InBodyPayload(
            weightKg: 89.5,
            skeletalMuscleMassKg: 38.2,
            bodyFatMassKg: 15.1,
            bodyFatPct: 16.9,
            totalBodyWaterL: 54.3,
            bmi: 25.8,
            basalMetabolicRate: 1850
        )
        let rows = [CSVScanRow(date: Date(), type: .inBody, source: .manual, payload: payload)]
        let outcome = CSVImporter.importScans(rows, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 1)

        let scans = try! context.fetch(FetchDescriptor<Scan>())
        XCTAssertEqual(scans.count, 1)
        XCTAssertEqual(scans.first?.source, ScanSource.imported.rawValue,
                       "imported scans are tagged .imported regardless of row source")

        await spy.waitForCalls(2)
        let saveScanCalls = await spy.calls.filter {
            if case .saveScanMetrics = $0 { return true } else { return false }
        }
        XCTAssertEqual(saveScanCalls.count, 1)
    }

    // MARK: - Edge-case parsing (BOM, line endings, quoted quotes)

    func testParseWeights_stripsUTF8BOM() {
        // Excel prepends \u{FEFF} when exporting UTF-8 CSVs on macOS.
        let csv = "\u{FEFF}date,weight,unit,notes\n2026-04-15T00:00:00.000Z,185.4,lb,"
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("BOM should be stripped") }
        XCTAssertEqual(parsed.rows.count, 1)
        XCTAssertEqual(parsed.rows[0].weight, 185.4)
    }

    func testDetectFormat_stripsUTF8BOM() {
        let csv = "\u{FEFF}date,weight,unit,notes\n"
        XCTAssertEqual(CSVFormat.detect(from: csv), .weights,
                       "format detection must ignore a leading BOM")
    }

    func testParseWeights_crlfLineEndings() {
        let csv = "date,weight,unit,notes\r\n2026-04-15T00:00:00.000Z,185.4,lb,\r\n2026-04-16T00:00:00.000Z,184.8,lb,\r\n"
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("CRLF must parse") }
        XCTAssertEqual(parsed.rows.count, 2)
    }

    func testParseWeights_classicMacCREndings() {
        let csv = "date,weight,unit,notes\r2026-04-15T00:00:00.000Z,185.4,lb,\r"
        let result = CSVImporter.parseWeights(csv)
        guard case .success(let parsed) = result else { return XCTFail("lone CR must parse") }
        XCTAssertEqual(parsed.rows.count, 1)
        XCTAssertEqual(parsed.rows[0].weight, 185.4)
    }

    func testRoundTrip_notesWithEmbeddedQuotes() {
        let today = Calendar.current.startOfDay(for: Date())
        context.insert(WeightEntry(weight: 185.4, unit: "lb", date: today, notes: "she said \"lighter\""))
        try! context.save()

        let csv = CSVExporter.exportWeights(context: context)
        // Sanity: the exporter must double the quotes per RFC 4180.
        XCTAssertTrue(csv.contains("\"\"lighter\"\""), "exporter should double-quote embedded quotes")

        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 1)
        XCTAssertEqual(parsed.rows[0].notes, "she said \"lighter\"",
                       "parser should collapse doubled quotes back to a single quote")
    }

    // MARK: - Multi-row partial failure

    func testImportWeights_multiRowPartialFailure_tallies() {
        // 4 valid rows interleaved with 2 invalid ones — the parser drops
        // the bad ones as issues, the importer persists the good ones.
        let csv = """
        date,weight,unit,notes
        2026-04-10T00:00:00.000Z,185.4,lb,good
        not-a-date,185.4,lb,bad date
        2026-04-11T00:00:00.000Z,185.0,lb,good
        2026-04-12T00:00:00.000Z,heavy,lb,bad weight
        2026-04-13T00:00:00.000Z,184.8,lb,good
        2026-04-14T00:00:00.000Z,184.5,lb,good
        """
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 4)
        XCTAssertEqual(parsed.issues.count, 2)

        let outcome = CSVImporter.importWeights(parsed.rows, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 4)
        XCTAssertEqual(outcome.failed, 0)

        let stored = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(stored.count, 4)
    }

    // MARK: - Scan source override

    func testImportScans_sourceAlwaysTaggedAsImported() {
        let payload = InBodyPayload(
            weightKg: 89.5, skeletalMuscleMassKg: 38.2, bodyFatMassKg: 15.1,
            bodyFatPct: 16.9, totalBodyWaterL: 54.3, bmi: 25.8, basalMetabolicRate: 1850
        )
        // Row claims source: .ocr, but persistence must rewrite to .imported
        // so the UI can distinguish fresh OCR from a bulk import.
        let rows = [
            CSVScanRow(date: Date(), type: .inBody, source: .ocr, payload: payload),
        ]
        CSVImporter.importScans(rows, context: context, conflictStrategy: .skip)

        let scans = try! context.fetch(FetchDescriptor<Scan>())
        XCTAssertEqual(scans.count, 1)
        XCTAssertEqual(scans[0].source, ScanSource.imported.rawValue,
                       "CSV imports must always be tagged .imported regardless of row source")
    }

    // MARK: - Format-dispatch helpers (parseAny / importAny)

    func testParseAny_weights() {
        let csv = "date,weight,unit,notes\n2026-04-15T00:00:00.000Z,185.4,lb,\n"
        let result = CSVImporter.parseAny(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.format, .weights)
        XCTAssertEqual(parsed.rowCount, 1)
    }

    func testParseAny_unknownFormat() {
        let csv = "timestamp,foo,bar\n"
        let result = CSVImporter.parseAny(csv)
        guard case .failure(let err) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(err, .unknownFormat)
    }

    func testImportAny_dispatchesToScans() async {
        let payload = InBodyPayload(
            weightKg: 89.5, skeletalMuscleMassKg: 38.2, bodyFatMassKg: 15.1,
            bodyFatPct: 16.9, totalBodyWaterL: 54.3, bmi: 25.8, basalMetabolicRate: 1850
        )
        let parsed: ParsedImport = .scans(CSVParseResult(
            rows: [CSVScanRow(date: Date(), type: .inBody, source: .manual, payload: payload)],
            issues: []
        ))
        let outcome = CSVImporter.importAny(parsed, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 1)

        let scans = try! context.fetch(FetchDescriptor<Scan>())
        XCTAssertEqual(scans.count, 1)

        await spy.waitForCalls(2)
        let saveScanCalls = await spy.calls.filter {
            if case .saveScanMetrics = $0 { return true } else { return false }
        }
        XCTAssertEqual(saveScanCalls.count, 1)
    }

    // MARK: - Real CSV fixtures (committed .csv files in the test bundle)

    private func loadFixture(_ name: String, ext: String = "csv") -> String {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let csv = String(data: data, encoding: .utf8) else {
            XCTFail("failed to load fixture \(name).\(ext)")
            return ""
        }
        return csv
    }

    func testFixture_weightsClean_parsesAllRows() {
        let csv = loadFixture("weights-clean")
        XCTAssertEqual(CSVFormat.detect(from: csv), .weights)
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 4)
        XCTAssertEqual(parsed.issues.count, 0)
        // Mixed units — last row is kg, rest are lb.
        XCTAssertEqual(parsed.rows.filter { $0.unit == "kg" }.count, 1)
        XCTAssertEqual(parsed.rows.filter { $0.unit == "lb" }.count, 3)
    }

    func testFixture_weightsBOM_parsesDespiteLeadingByteOrderMark() {
        let csv = loadFixture("weights-bom")
        // File starts with \u{FEFF} — detect must handle it.
        XCTAssertEqual(CSVFormat.detect(from: csv), .weights)
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 2)
    }

    func testFixture_weightsCRLF_parsesWindowsLineEndings() {
        let csv = loadFixture("weights-crlf")
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 4)
    }

    func testFixture_weightsQuotedNotes_decodesEscapedQuotes() {
        let csv = loadFixture("weights-quoted-notes")
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 3)
        // Row 1 has an embedded comma.
        XCTAssertEqual(parsed.rows[0].notes, "morning, pre-coffee")
        // Row 2 has embedded doubled quotes ("" → ").
        XCTAssertEqual(parsed.rows[1].notes, "she said \"lighter today\"")
        // Row 3 has a plain, unquoted note.
        XCTAssertEqual(parsed.rows[2].notes, "plain note")
    }

    func testFixture_measurementsClean_importsAllTypes() async {
        let csv = loadFixture("measurements-clean")
        let parsed = try! CSVImporter.parseMeasurements(csv).get()
        XCTAssertEqual(parsed.rows.count, 4)

        let outcome = CSVImporter.importMeasurements(parsed.rows, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 4)

        // Only two rows are waist → two HK mirror calls, no more.
        await spy.waitForCalls(2)
        let waistCalls = await spy.calls.filter {
            if case .saveWaist = $0 { return true } else { return false }
        }
        XCTAssertEqual(waistCalls.count, 2, "only waist rows should fire HK mirror")
    }

    func testFixture_scansClean_importsAsImportedSource() {
        let csv = loadFixture("scans-clean")
        let parsed = try! CSVImporter.parseScans(csv).get()
        XCTAssertEqual(parsed.rows.count, 2)

        let outcome = CSVImporter.importScans(parsed.rows, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 2)

        let scans = try! context.fetch(FetchDescriptor<Scan>())
        // Both rows had different original sources (.manual, .ocr) —
        // persistence must rewrite both to .imported.
        XCTAssertEqual(scans.allSatisfy { $0.source == ScanSource.imported.rawValue }, true)
    }

    // MARK: - Flexible header format (role-based column mapping)
    //
    // The importer accepts any header shape it can resolve to the
    // required roles. These tests exercise the most common real-world
    // variations: slash-separated dates, split date+time columns, unit
    // encoded in the header, and synonym-mapped column names.

    func testFlexible_slashDatesAndSplitTime_detectsAsWeights() {
        let csv = "Date,Time,Weight (lb),Note\n\"5/26/21\",\"00:54:04\",\"184.4\",\"\""
        XCTAssertEqual(CSVFormat.detect(from: csv), .weights,
                       "a file with date+weight columns must resolve to .weights")
    }

    func testFlexible_slashDatesAndSplitTime_parsesRow() {
        let csv = """
        Date,Time,Weight (lb),Note
        "5/26/21","00:54:04","184.4",""
        """
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 1)
        XCTAssertEqual(parsed.rows[0].weight, 184.4)
        XCTAssertEqual(parsed.rows[0].unit, "lb",
                       "unit resolved from the parenthesized header hint 'Weight (lb)'")
        XCTAssertNil(parsed.rows[0].notes, "empty quoted note becomes nil")

        // Confirm 2-digit year anchors to 2000s, not 1900s.
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: parsed.rows[0].date)
        XCTAssertEqual(comps.year, 2021)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 26)
    }

    func testFlexible_unitFromHeaderHint_overridesDefault() {
        // Header says `Weight (kg)` — unit column is absent, but the hint
        // must take priority over the defaultUnit fallback.
        let csv = """
        Date,Weight (kg)
        2026-04-15,80.5
        """
        let parsed = try! CSVImporter.parseWeights(csv, defaultUnit: "lb").get()
        XCTAssertEqual(parsed.rows[0].unit, "kg")
    }

    func testFlexible_unitFromExplicitColumn_overridesHeaderHint() {
        // If both the column and the header disagree, the column wins.
        // This matches RFC-style "most specific" resolution.
        let csv = """
        Date,Weight (lb),Unit
        2026-04-15,180.0,kg
        """
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows[0].unit, "kg",
                       "explicit Unit column must override the '(lb)' header hint")
    }

    func testFlexible_unitFallsBackToDefault_whenNothingIdentifiesIt() {
        let csv = """
        Date,Weight
        2026-04-15,180.0
        """
        let parsedLb = try! CSVImporter.parseWeights(csv, defaultUnit: "lb").get()
        XCTAssertEqual(parsedLb.rows[0].unit, "lb")

        let parsedKg = try! CSVImporter.parseWeights(csv, defaultUnit: "kg").get()
        XCTAssertEqual(parsedKg.rows[0].unit, "kg")
    }

    func testFlexible_parseAnyDispatchesToWeights() {
        let csv = """
        Date,Time,Weight (lb),Note
        "4/22/26","07:14:27","199.6",""
        """
        let result = CSVImporter.parseAny(csv)
        guard case .success(let parsed) = result else { return XCTFail("expected success") }
        XCTAssertEqual(parsed.format, .weights)
        XCTAssertEqual(parsed.rowCount, 1)
    }

    func testFlexible_importsThroughSameWeightsPersistencePath() async {
        let csv = """
        Date,Time,Weight (lb),Note
        "5/26/21","00:54:04","184.4",""
        "4/22/26","07:14:27","199.6",""
        """
        let parsed = try! CSVImporter.parseAny(csv).get()
        let outcome = CSVImporter.importAny(parsed, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 2)

        let stored = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(stored.count, 2)
        XCTAssertTrue(stored.allSatisfy { $0.unit == "lb" })

        // HK mirror fires for every imported row, same as Baseline's own format.
        await spy.waitForCalls(2)
        let saves = await spy.calls.filter {
            if case .saveWeight = $0 { return true } else { return false }
        }
        XCTAssertEqual(saves.count, 2)
    }

    func testFlexible_multipleRowsSameDay_skipKeepsFirst() {
        let csv = """
        Date,Time,Weight (lb),Note
        "5/26/21","00:54:04","184.4",""
        "5/26/21","09:49:24","183.3",""
        """
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 2)

        let outcome = CSVImporter.importWeights(parsed.rows, context: context, conflictStrategy: .skip)
        XCTAssertEqual(outcome.inserted, 1)
        XCTAssertEqual(outcome.skipped, 1)

        let stored = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].weight, 184.4, "first row wins on .skip")
    }

    func testFlexible_multipleRowsSameDay_overwriteKeepsLast() {
        let csv = """
        Date,Time,Weight (lb),Note
        "5/26/21","00:54:04","184.4",""
        "5/26/21","09:49:24","183.3",""
        """
        let parsed = try! CSVImporter.parseWeights(csv).get()
        let outcome = CSVImporter.importWeights(parsed.rows, context: context, conflictStrategy: .overwrite)
        XCTAssertEqual(outcome.overwritten, 1)
        XCTAssertEqual(outcome.inserted, 1)

        let stored = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].weight, 183.3, "last row wins on .overwrite")
    }

    func testFixture_slashDatesAndSplitTime_parsesRealExportSlice() {
        // Fixture captures the shape: "M/D/YY" dates, split HH:mm:ss
        // time column, unit in the header — a common third-party export.
        let csv = loadFixture("weights-slash-dates-split-time")
        XCTAssertEqual(CSVFormat.detect(from: csv), .weights)
        let parsed = try! CSVImporter.parseWeights(csv).get()
        XCTAssertEqual(parsed.rows.count, 17)
        XCTAssertEqual(parsed.issues.count, 0)
        XCTAssertEqual(parsed.rows.first?.weight, 184.4)
        XCTAssertEqual(parsed.rows.last?.weight, 199.6)
        XCTAssertTrue(parsed.rows.allSatisfy { $0.unit == "lb" })
    }

    // MARK: - Length unit flexibility (measurements)

    func testFlexible_measurementsInInches_convertsToCm() {
        // Header hint `Value (in)` should trigger in→cm conversion.
        let csv = """
        Date,Type,Value (in)
        2026-04-15,waist,33.27
        """
        let parsed = try! CSVImporter.parseMeasurements(csv).get()
        XCTAssertEqual(parsed.rows.count, 1)
        // 33.27 in * 2.54 = 84.5058 cm
        XCTAssertEqual(parsed.rows[0].valueCm, 84.5058, accuracy: 0.0001)
    }

    func testFlexible_measurementsInCm_passesThrough() {
        let csv = """
        Date,Type,Value (cm)
        2026-04-15,waist,84.5
        """
        let parsed = try! CSVImporter.parseMeasurements(csv).get()
        XCTAssertEqual(parsed.rows[0].valueCm, 84.5)
    }

    func testImportScans_overwriteClearsStaleHKSamples() async {
        let today = Date()
        let existingPayload = InBodyPayload(
            weightKg: 90.0, skeletalMuscleMassKg: 38.0, bodyFatMassKg: 16.0,
            bodyFatPct: 17.8, totalBodyWaterL: 55.0, bmi: 26.0, basalMetabolicRate: 1800
        )
        let existingData = try! JSONEncoder().encode(existingPayload)
        let existing = Scan(date: today, type: .inBody, source: .manual, payload: existingData)
        context.insert(existing)
        try! context.save()
        let existingID = existing.id

        await spy.reset()

        let newPayload = InBodyPayload(
            weightKg: 89.5, skeletalMuscleMassKg: 38.2, bodyFatMassKg: 15.1,
            bodyFatPct: 16.9, totalBodyWaterL: 54.3, bmi: 25.8, basalMetabolicRate: 1850
        )
        let rows = [CSVScanRow(date: today, type: .inBody, source: .ocr, payload: newPayload)]
        let outcome = CSVImporter.importScans(rows, context: context, conflictStrategy: .overwrite)
        XCTAssertEqual(outcome.overwritten, 1)

        await spy.waitForCalls(3)
        let calls = await spy.calls
        XCTAssertTrue(calls.contains(.delete(sourceID: existingID)),
                      "stale HK samples for overwritten scan should be deleted by UUID")
    }
}
