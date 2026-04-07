import XCTest
import SwiftData
@testable import Baseline

private typealias Measurement = Baseline.Measurement

final class HistoryViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, Scan.self, Measurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testRefreshEmptyWhenNoEntries() {
        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()
        XCTAssertTrue(vm.entries.isEmpty)
    }

    func testRefreshSortsReverseChronological() {
        let cal = Calendar.current
        let today = Date()
        let d1 = cal.date(byAdding: .day, value: -2, to: today)!
        let d2 = cal.date(byAdding: .day, value: -1, to: today)!
        context.insert(WeightEntry(weight: 196.0, date: d1))
        context.insert(WeightEntry(weight: 197.0, date: d2))
        context.insert(WeightEntry(weight: 198.0, date: today))
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()

        XCTAssertEqual(vm.entries.count, 3)
        XCTAssertEqual(vm.entries[0].weight, 198.0)
        XCTAssertEqual(vm.entries[1].weight, 197.0)
        XCTAssertEqual(vm.entries[2].weight, 196.0)
    }

    func testDeltaForReturnsDifferenceFromPreviousChronologically() throws {
        let cal = Calendar.current
        let today = Date()
        let d1 = cal.date(byAdding: .day, value: -2, to: today)!
        let d2 = cal.date(byAdding: .day, value: -1, to: today)!
        context.insert(WeightEntry(weight: 196.0, date: d1))
        context.insert(WeightEntry(weight: 197.0, date: d2))
        context.insert(WeightEntry(weight: 198.5, date: today))
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()

        // Newest row (today) delta vs previous (yesterday: 197.0) = +1.5
        let newestDelta = try XCTUnwrap(vm.delta(for: vm.entries[0]))
        XCTAssertEqual(newestDelta, 1.5, accuracy: 0.01)

        // Middle row delta vs prior (196.0) = +1.0
        let midDelta = try XCTUnwrap(vm.delta(for: vm.entries[1]))
        XCTAssertEqual(midDelta, 1.0, accuracy: 0.01)
    }

    func testDeltaNilForOldestEntry() {
        let cal = Calendar.current
        let today = Date()
        let d1 = cal.date(byAdding: .day, value: -1, to: today)!
        context.insert(WeightEntry(weight: 196.0, date: d1))
        context.insert(WeightEntry(weight: 197.0, date: today))
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()

        // Oldest entry (last in reverse-chrono list) has no prior entry.
        XCTAssertNil(vm.delta(for: vm.entries.last!))
    }

    func testDeleteRemovesEntry() {
        let entry = WeightEntry(weight: 197.0, date: Date())
        context.insert(entry)
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 1)

        vm.delete(entry)

        XCTAssertTrue(vm.entries.isEmpty)
        let all = try! context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertTrue(all.isEmpty)
    }

    func testUpdateChangesWeightAndNotes() {
        let entry = WeightEntry(weight: 197.0, date: Date(), notes: "old")
        context.insert(entry)
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()

        vm.update(entry, weight: 198.5, notes: "new note")

        XCTAssertEqual(entry.weight, 198.5)
        XCTAssertEqual(entry.notes, "new note")
        XCTAssertEqual(vm.entries.first?.weight, 198.5)
    }

    func testUpdateEmptyNotesStoredAsNil() {
        let entry = WeightEntry(weight: 197.0, date: Date(), notes: "old")
        context.insert(entry)
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()

        vm.update(entry, weight: 197.0, notes: "   ")

        XCTAssertNil(entry.notes)
    }
}
