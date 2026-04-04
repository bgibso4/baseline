import XCTest
import SwiftData
@testable import Baseline

final class WeighInViewModelTests: XCTestCase {
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

    func testDefaultsToLastWeight() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        XCTAssertEqual(vm.currentWeight, 197.4)
    }

    func testDefaultsTo150WhenNoHistory() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: nil, unit: "lb")
        XCTAssertEqual(vm.currentWeight, 150.0)
    }

    func testIncrementByStepSize() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.stepSize = 0.1
        vm.increment()
        XCTAssertEqual(vm.currentWeight, 197.5, accuracy: 0.01)
    }

    func testDecrementByStepSize() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.stepSize = 0.5
        vm.decrement()
        XCTAssertEqual(vm.currentWeight, 196.9, accuracy: 0.01)
    }

    func testToggleStepSize() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        XCTAssertEqual(vm.stepSize, 0.1)
        vm.cycleStepSize()
        XCTAssertEqual(vm.stepSize, 0.5)
        vm.cycleStepSize()
        XCTAssertEqual(vm.stepSize, 1.0)
        vm.cycleStepSize()
        XCTAssertEqual(vm.stepSize, 0.1)
    }

    func testSaveCreatesNewEntry() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.currentWeight = 198.0
        vm.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, 198.0)
    }

    func testSaveUpdatesExistingTodayEntry() {
        let existing = WeightEntry(weight: 197.4, date: Date())
        context.insert(existing)
        try! context.save()

        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.currentWeight = 198.0
        vm.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1, "Should update existing, not create duplicate")
        XCTAssertEqual(entries.first?.weight, 198.0)
    }
}
