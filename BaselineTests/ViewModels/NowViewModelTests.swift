import XCTest
import SwiftData
@testable import Baseline

private typealias Measurement = Baseline.Measurement

final class NowViewModelTests: XCTestCase {
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

    func testTodayEntryNilWhenNoEntries() {
        let vm = NowViewModel(modelContext: context)
        vm.refresh()
        XCTAssertNil(vm.todayEntry)
    }

    func testTodayEntryFoundWhenExists() {
        let entry = WeightEntry(weight: 197.4, date: Date())
        context.insert(entry)
        try! context.save()

        let vm = NowViewModel(modelContext: context)
        vm.refresh()
        XCTAssertNotNil(vm.todayEntry)
        XCTAssertEqual(vm.todayEntry?.weight, 197.4)
    }

    func testDeltaFromYesterday() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayEntry = WeightEntry(weight: 197.0, date: yesterday)
        let todayEntry = WeightEntry(weight: 197.6, date: Date())
        context.insert(yesterdayEntry)
        context.insert(todayEntry)
        try! context.save()

        let vm = NowViewModel(modelContext: context)
        vm.refresh()
        let delta = try XCTUnwrap(vm.delta)
        XCTAssertEqual(delta, 0.6, accuracy: 0.01)
    }

    func testDeltaNilWhenOnlyOneEntry() {
        let entry = WeightEntry(weight: 197.4, date: Date())
        context.insert(entry)
        try! context.save()

        let vm = NowViewModel(modelContext: context)
        vm.refresh()
        XCTAssertNil(vm.delta)
    }

    func testPreviousEntryIsMostRecentBeforeToday() throws {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let oldEntry = WeightEntry(weight: 195.0, date: threeDaysAgo)
        let todayEntry = WeightEntry(weight: 197.4, date: Date())
        context.insert(oldEntry)
        context.insert(todayEntry)
        try! context.save()

        let vm = NowViewModel(modelContext: context)
        vm.refresh()
        let delta = try XCTUnwrap(vm.delta)
        XCTAssertEqual(delta, 2.4, accuracy: 0.01)
    }

    func testRecentEntriesForSparkline() {
        for i in 0..<10 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let entry = WeightEntry(weight: 195.0 + Double(i) * 0.3, date: date)
            context.insert(entry)
        }
        try! context.save()

        let vm = NowViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.recentWeights.count, 10)
    }

    func testLastWeightForWeighInDefault() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let entry = WeightEntry(weight: 197.4, date: yesterday)
        context.insert(entry)
        try! context.save()

        let vm = NowViewModel(modelContext: context)
        vm.refresh()
        let lastWeight = try XCTUnwrap(vm.lastWeight)
        XCTAssertEqual(lastWeight, 197.4)
    }
}
