import XCTest
import SwiftData
@testable import Baseline

private typealias Measurement = Baseline.Measurement

final class WeighInViewModelTests: XCTestCase {
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

    func testDefaultsToLastWeight() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        XCTAssertEqual(vm.currentWeight, 197.4)
    }

    func testDefaultsTo150WhenNoHistory() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: nil, unit: "lb")
        XCTAssertEqual(vm.currentWeight, 150.0)
    }

    func testIncrementByPointOne() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.increment()
        XCTAssertEqual(vm.currentWeight, 197.5, accuracy: 0.01)
    }

    func testDecrementByPointOne() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.decrement()
        XCTAssertEqual(vm.currentWeight, 197.3, accuracy: 0.01)
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

    func testSavePersistsNotes() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.currentWeight = 198.0
        vm.notes = "After long run"
        vm.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.first?.notes, "After long run")
    }

    func testSaveEmptyNotesStoredAsNil() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.currentWeight = 198.0
        vm.notes = "   "
        vm.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertNil(entries.first?.notes)
    }
}
