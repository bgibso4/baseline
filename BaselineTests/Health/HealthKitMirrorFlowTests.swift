import XCTest
import SwiftData
import HealthKit
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// End-to-end tests for the HealthKit mirror wiring across all three record
/// types (weight entries, scans, measurements). Each test substitutes a spy
/// for `HealthKitManager.mirror`, triggers the relevant VM flow, and asserts
/// the exact sequence of save/delete calls the VM produced.
///
/// Verified behaviors:
///  - New records write fresh HK samples tagged with the record's UUID
///  - Edits delete the prior sample for the same UUID before writing again
///  - Overwrites (user chose "Replace") clean up the replaced record's samples
///  - Deletes clear HK samples
///  - Non-waist measurements never touch HealthKit
final class HealthKitMirrorFlowTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var spy: SpyHealthKitMirror!
    var originalMirror: HealthMirroring!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, Scan.self, Measurement.self, SyncState.self, Goal.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        spy = SpyHealthKitMirror()
        originalMirror = HealthKitManager.mirror
        HealthKitManager.mirror = spy

        // Tests assert literal kg values and avoid lb/kg conversions in payloads.
        UserDefaults.standard.set("kg", forKey: "weightUnit")
        UserDefaults.standard.set("cm", forKey: "lengthUnit")
    }

    override func tearDown() async throws {
        // Drain any pending VM-spawned HK tasks before restoring the mirror.
        // Without this, a Task spawned by this test can fire into the NEXT
        // test's spy and corrupt its recorded call sequence.
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
        HealthKitManager.mirror = originalMirror
        originalMirror = nil
        spy = nil
        container = nil
        context = nil
        UserDefaults.standard.removeObject(forKey: "weightUnit")
        UserDefaults.standard.removeObject(forKey: "lengthUnit")
        try await super.tearDown()
    }

    // MARK: - Weight Entry Flows

    func testWeightFirstSave_deletesSelfThenSavesWeight() async {
        let vm = WeighInViewModel(modelContext: context, lastWeight: nil, unit: "kg")
        vm.currentWeight = 75.0
        vm.save(date: Date())

        await spy.waitForCalls(2)
        let calls = await spy.calls
        let entry = try! context.fetch(FetchDescriptor<WeightEntry>()).first!

        XCTAssertEqual(calls, [
            .delete(sourceID: entry.id),
            .saveWeight(entryID: entry.id),
        ], "First save must delete-then-save so the same-entry-different-attempt case is always idempotent. Actual: \(calls)")
    }

    func testWeightSameDayOverwrite_reusesOriginalEntryID() async {
        // First save
        let vm = WeighInViewModel(modelContext: context, lastWeight: nil, unit: "kg")
        vm.currentWeight = 70.0
        vm.save(date: Date())
        await spy.waitForCalls(2)
        let originalID = try! context.fetch(FetchDescriptor<WeightEntry>()).first!.id
        await spy.reset()

        // Second save on same day updates the existing entry in place
        vm.currentWeight = 71.0
        vm.save(date: Date())
        await spy.waitForCalls(2)

        let calls = await spy.calls
        let allEntries = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(allEntries.count, 1, "Same-day save should update in place, not insert")
        XCTAssertEqual(allEntries.first?.id, originalID, "Same-day save must reuse the entry's UUID")
        XCTAssertEqual(calls, [
            .delete(sourceID: originalID),
            .saveWeight(entryID: originalID),
        ], "Same-day overwrite must delete the stale HK sample (by the existing entry's id) then write a fresh one")
    }

    func testWeightEditDateChange_deletesSelfThenSaves() async {
        let day1 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let originalEntry = WeightEntry(weight: 70, unit: "kg", date: day1)
        context.insert(originalEntry)
        try! context.save()
        let originalID = originalEntry.id

        let historyVM = HistoryViewModel(modelContext: context)
        historyVM.refresh()

        // Move the entry to a different date with no conflict
        let day2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        historyVM.update(originalEntry, weight: 71, notes: "", date: day2)

        await spy.waitForCalls(2)
        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: originalID),
            .saveWeight(entryID: originalID),
        ], "Date-change edit must wipe stale HK samples for this entry (they carry the old date) and rewrite at the new date — same UUID, same behaviour as replace-in-place. Actual: \(calls)")
    }

    func testWeightEditDateOverwrite_deletesConflictThenSelfThenSaves() async {
        let day1 = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let day2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let movedEntry = WeightEntry(weight: 70, unit: "kg", date: day1)
        let victimEntry = WeightEntry(weight: 73, unit: "kg", date: day2)
        context.insert(movedEntry)
        context.insert(victimEntry)
        try! context.save()

        let movedID = movedEntry.id
        let victimID = victimEntry.id

        let historyVM = HistoryViewModel(modelContext: context)
        historyVM.refresh()
        historyVM.update(movedEntry, weight: 71, notes: "", date: day2)

        await spy.waitForCalls(3)
        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: victimID),
            .delete(sourceID: movedID),
            .saveWeight(entryID: movedID),
        ], "Overwriting another entry's date must clean up the victim's HK samples AND the moved entry's prior-date samples before writing. Actual: \(calls)")
        let remaining = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(remaining.count, 1, "Victim entry must be deleted from SwiftData too")
    }

    func testWeightDelete_removesHKSamples() async {
        let entry = WeightEntry(weight: 70, unit: "kg", date: Date())
        context.insert(entry)
        try! context.save()
        let entryID = entry.id

        let historyVM = HistoryViewModel(modelContext: context)
        historyVM.refresh()
        historyVM.delete(entry)

        await spy.waitForCalls(1)
        let calls = await spy.calls
        XCTAssertEqual(calls, [.delete(sourceID: entryID)], "Delete must remove HK samples by the deleted entry's id. Actual: \(calls)")
    }

    // MARK: - Scan Flows

    func testNewScanSave_deletesSelfThenSavesMetrics() async throws {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectedType = .inBody
        vm.selectedSource = .manual
        seedCoreFields(vm: vm)
        vm.scanDate = Date()

        try vm.save()
        await spy.waitForCalls(2)

        let scan = try context.fetch(FetchDescriptor<Scan>()).first!
        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: scan.id),
            .saveScanMetrics(scanID: scan.id),
        ], "New scan save must be idempotent — delete-by-id (no-op here) then write. Actual: \(calls)")
    }

    func testScanEditSameDate_deletesSelfThenSaves() async throws {
        // Seed an existing scan
        let existingScan = makeInBodyScan(date: Date())
        context.insert(existingScan)
        try context.save()
        let scanID = existingScan.id

        // Edit it (same date, different weight)
        let vm = ScanEntryViewModel(modelContext: context)
        let existingPayload = try extractPayload(existingScan)
        vm.loadForEdit(scan: existingScan, payload: existingPayload, massPref: "kg")
        vm.weightKg = "82"

        try vm.save()
        await spy.waitForCalls(2)

        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: scanID),
            .saveScanMetrics(scanID: scanID),
        ], "Scan edit must wipe prior HK samples tagged with this scan's id before rewriting. Actual: \(calls)")
    }

    func testScanEditDateChange_deletesSelfThenSaves() async throws {
        let day1 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let day2 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!

        let scan = makeInBodyScan(date: day1)
        context.insert(scan)
        try context.save()
        let scanID = scan.id

        let vm = ScanEntryViewModel(modelContext: context)
        let payload = try extractPayload(scan)
        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")
        vm.scanDate = day2

        try vm.save()
        await spy.waitForCalls(2)

        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: scanID),
            .saveScanMetrics(scanID: scanID),
        ], "Scan date-change edit must delete the old-date samples (same UUID) before writing at the new date. Actual: \(calls)")
    }

    func testScanEditDateOverwrite_deletesConflictThenSelfThenSaves() async throws {
        let day1 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let day2 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!

        let movedScan = makeInBodyScan(date: day1, weightKg: 80)
        let victimScan = makeInBodyScan(date: day2, weightKg: 85)
        context.insert(movedScan)
        context.insert(victimScan)
        try context.save()
        let movedID = movedScan.id
        let victimID = victimScan.id

        let vm = ScanEntryViewModel(modelContext: context)
        let payload = try extractPayload(movedScan)
        vm.loadForEdit(scan: movedScan, payload: payload, massPref: "kg")
        vm.scanDate = day2

        try vm.save()
        await spy.waitForCalls(3)

        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: victimID),
            .delete(sourceID: movedID),
            .saveScanMetrics(scanID: movedID),
        ], "Overwrite-on-edit must clean up both the victim's AND the moved scan's HK samples before writing. Actual: \(calls)")
        let remaining = try context.fetch(FetchDescriptor<Scan>())
        XCTAssertEqual(remaining.count, 1, "Victim scan must be deleted from SwiftData")
        XCTAssertEqual(remaining.first?.id, movedID, "Surviving scan must be the edited one")
    }

    func testNewScanOnOccupiedDate_deletesConflictThenSelfThenSaves() async throws {
        // Existing scan on the same date
        let today = Date()
        let existingScan = makeInBodyScan(date: today, weightKg: 80)
        context.insert(existingScan)
        try context.save()
        let victimID = existingScan.id

        // Fresh scan flow (not loadForEdit) saving to the same date
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectedType = .inBody
        vm.selectedSource = .manual
        seedCoreFields(vm: vm)
        vm.scanDate = today

        try vm.save()
        await spy.waitForCalls(3)

        let calls = await spy.calls
        let newScan = try context.fetch(FetchDescriptor<Scan>()).first!
        XCTAssertNotEqual(newScan.id, victimID, "New scan should have a fresh id")
        XCTAssertEqual(calls, [
            .delete(sourceID: victimID),
            .delete(sourceID: newScan.id),
            .saveScanMetrics(scanID: newScan.id),
        ], "Replacing an existing scan on the same date must delete the victim's HK samples. Actual: \(calls)")
    }

    func testScanDelete_removesHKSamples() async throws {
        let scan = makeInBodyScan(date: Date())
        context.insert(scan)
        try context.save()
        let scanID = scan.id

        let vm = BodyViewModel(modelContext: context)
        vm.deleteScan(scan)
        await spy.waitForCalls(1)

        let calls = await spy.calls
        XCTAssertEqual(calls, [.delete(sourceID: scanID)], "Scan delete must remove HK samples by scan.id. Actual: \(calls)")
    }

    // MARK: - Measurement Flows

    func testWaistMeasurementSave_writesHKSample() async {
        let vm = BodyViewModel(modelContext: context)
        vm.saveMeasurement(type: .waist, valueCm: 82, notes: nil)
        await spy.waitForCalls(1)

        let saved = try! context.fetch(FetchDescriptor<Measurement>()).first!
        let calls = await spy.calls
        XCTAssertEqual(calls, [.saveWaist(sourceID: saved.id)], "Waist save must write an HK sample tagged with measurement.id. Actual: \(calls)")
    }

    func testNonWaistMeasurementSave_doesNotTouchHealthKit() async {
        let vm = BodyViewModel(modelContext: context)
        vm.saveMeasurement(type: .neck, valueCm: 40, notes: nil)

        // Poll a short window to surface any stray HK call
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let calls = await spy.calls
        XCTAssertTrue(calls.isEmpty, "Non-waist measurements must not touch HealthKit. Actual: \(calls)")
    }

    func testWaistMeasurementDelete_removesHKSamples() async {
        let measurement = Measurement(date: Date(), type: .waist, valueCm: 82)
        context.insert(measurement)
        try! context.save()
        let sourceID = measurement.id

        let vm = BodyViewModel(modelContext: context)
        vm.deleteMeasurement(measurement)
        await spy.waitForCalls(1)

        let calls = await spy.calls
        XCTAssertEqual(calls, [.delete(sourceID: sourceID)], "Waist delete must remove HK samples by measurement.id. Actual: \(calls)")
    }

    func testNonWaistMeasurementDelete_doesNotTouchHealthKit() async {
        let measurement = Measurement(date: Date(), type: .armLeft, valueCm: 35)
        context.insert(measurement)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.deleteMeasurement(measurement)

        try? await Task.sleep(nanoseconds: 150_000_000)

        let calls = await spy.calls
        XCTAssertTrue(calls.isEmpty, "Non-waist delete must not touch HealthKit. Actual: \(calls)")
    }

    func testWaistMeasurementEditSameDate_deletesSelfThenSaves() async {
        let measurement = Measurement(date: Date(), type: .waist, valueCm: 82)
        context.insert(measurement)
        try! context.save()
        let sourceID = measurement.id

        let vm = BodyViewModel(modelContext: context)
        vm.editMeasurement(measurement, newValueCm: 81, notes: nil, date: measurement.date)
        await spy.waitForCalls(2)

        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: sourceID),
            .saveWaist(sourceID: sourceID),
        ], "Waist edit must delete prior sample tagged with measurement.id then rewrite. Actual: \(calls)")
    }

    func testWaistMeasurementEditOverwrite_deletesConflictThenSelfThenSaves() async {
        let day1 = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let day2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let movedMeasurement = Measurement(date: day1, type: .waist, valueCm: 82)
        let victimMeasurement = Measurement(date: day2, type: .waist, valueCm: 85)
        context.insert(movedMeasurement)
        context.insert(victimMeasurement)
        try! context.save()
        let movedID = movedMeasurement.id
        let victimID = victimMeasurement.id

        let vm = BodyViewModel(modelContext: context)
        vm.editMeasurement(movedMeasurement, newValueCm: 81, notes: nil, date: day2)
        await spy.waitForCalls(3)

        let calls = await spy.calls
        XCTAssertEqual(calls, [
            .delete(sourceID: victimID),
            .delete(sourceID: movedID),
            .saveWaist(sourceID: movedID),
        ], "Waist edit-overwrite must clean up BOTH the victim's samples AND the moved measurement's prior-date samples. Actual: \(calls)")
        let remaining = try! context.fetch(FetchDescriptor<Measurement>())
        XCTAssertEqual(remaining.count, 1, "Victim measurement must be removed from SwiftData")
    }

    func testNonWaistMeasurementEdit_doesNotTouchHealthKit() async {
        let measurement = Measurement(date: Date(), type: .neck, valueCm: 40)
        context.insert(measurement)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.editMeasurement(measurement, newValueCm: 39, notes: nil, date: measurement.date)

        try? await Task.sleep(nanoseconds: 150_000_000)

        let calls = await spy.calls
        XCTAssertTrue(calls.isEmpty, "Non-waist edit must not touch HealthKit. Actual: \(calls)")
    }

    // MARK: - Helpers

    private func makePayload(weightKg: Double = 80, bodyFatPct: Double = 20) -> InBodyPayload {
        InBodyPayload(
            weightKg: weightKg,
            skeletalMuscleMassKg: 35,
            bodyFatMassKg: weightKg * bodyFatPct / 100,
            bodyFatPct: bodyFatPct,
            totalBodyWaterL: 40,
            bmi: 25,
            basalMetabolicRate: 1800
        )
    }

    private func makeInBodyScan(
        date: Date,
        weightKg: Double = 80,
        bodyFatPct: Double = 20
    ) -> Scan {
        let payload = makePayload(weightKg: weightKg, bodyFatPct: bodyFatPct)
        let data = try! JSONEncoder().encode(payload)
        return Scan(
            date: Calendar.current.startOfDay(for: date),
            type: .inBody,
            source: .manual,
            payload: data
        )
    }

    private func extractPayload(_ scan: Scan) throws -> InBodyPayload {
        let content = try scan.decoded()
        guard case .inBody(let p) = content else {
            throw NSError(domain: "HealthKitMirrorFlowTests", code: 1)
        }
        return p
    }

    /// Populates the 7 required core fields so `ScanEntryViewModel.save()`
    /// can build a valid InBodyPayload. Uses kg directly — matches `weightUnit`
    /// preference set in `setUp()` to avoid unit conversion skew.
    private func seedCoreFields(vm: ScanEntryViewModel) {
        vm.weightKg = "80"
        vm.skeletalMuscleMassKg = "35"
        vm.bodyFatMassKg = "16"
        vm.bodyFatPct = "20"
        vm.totalBodyWaterL = "40"
        vm.bmi = "25"
        vm.basalMetabolicRate = "1800"
    }
}
