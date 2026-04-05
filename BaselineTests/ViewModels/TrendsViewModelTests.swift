import XCTest
import SwiftData
@testable import Baseline

final class TrendsViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testTimeRangeFiltering() {
        // Insert 400 days of data (one entry per day).
        let today = Calendar.current.startOfDay(for: Date())
        for i in 0..<400 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            context.insert(WeightEntry(weight: 195.0 + sin(Double(i) * 0.1) * 3, date: date))
        }
        try! context.save()

        let vm = TrendsViewModel(modelContext: context)

        vm.timeRange = .month
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 30)

        vm.timeRange = .sixMonths
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 180)

        vm.timeRange = .year
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 365)

        vm.timeRange = .all
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 400)
    }

    func testMovingAverage7Day() {
        // Insert 14 days of data with an alternating pattern: 196, 198, 196, 198...
        let today = Calendar.current.startOfDay(for: Date())
        for i in 0..<14 {
            let date = Calendar.current.date(byAdding: .day, value: -(13 - i), to: today)!
            let weight = i % 2 == 0 ? 196.0 : 198.0
            context.insert(WeightEntry(weight: weight, date: date))
        }
        try! context.save()

        let vm = TrendsViewModel(modelContext: context)
        vm.timeRange = .month
        vm.refresh()

        let ma = vm.movingAverage
        XCTAssertFalse(ma.isEmpty)
        // 14 entries, window 7 -> 8 MA points.
        XCTAssertEqual(ma.count, 8)
        // Each window of 7 alternating 196/198 values averages near 197.
        for point in ma {
            XCTAssertEqual(point.value, 197.0, accuracy: 0.2)
        }
    }

    func testWeightRange() {
        let today = Calendar.current.startOfDay(for: Date())
        context.insert(WeightEntry(weight: 195.0, date: Calendar.current.date(byAdding: .day, value: -2, to: today)!))
        context.insert(WeightEntry(weight: 200.0, date: Calendar.current.date(byAdding: .day, value: -1, to: today)!))
        context.insert(WeightEntry(weight: 197.0, date: today))
        try! context.save()

        let vm = TrendsViewModel(modelContext: context)
        vm.timeRange = .month
        vm.refresh()
        XCTAssertEqual(vm.minWeight, 195.0)
        XCTAssertEqual(vm.maxWeight, 200.0)
    }

    func testEmptyResultsReturnZeroStats() {
        let vm = TrendsViewModel(modelContext: context)
        vm.timeRange = .month
        vm.refresh()

        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertEqual(vm.minWeight, 0)
        XCTAssertEqual(vm.maxWeight, 0)
        XCTAssertTrue(vm.movingAverage.isEmpty)
    }

    func testMovingAverageSkippedWhenBelowWindow() {
        let today = Calendar.current.startOfDay(for: Date())
        for i in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            context.insert(WeightEntry(weight: 196.0, date: date))
        }
        try! context.save()

        let vm = TrendsViewModel(modelContext: context)
        vm.timeRange = .month
        vm.refresh()

        XCTAssertEqual(vm.entries.count, 5)
        XCTAssertTrue(vm.movingAverage.isEmpty)
    }
}
