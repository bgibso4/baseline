import XCTest
import SwiftData
@testable import Baseline

final class WeightEntryTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testCreateWeightEntry() {
        let entry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        context.insert(entry)
        try! context.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, 197.4)
        XCTAssertEqual(entries.first?.unit, "lb")
    }

    func testDefaultUnitIsLb() {
        let entry = WeightEntry(weight: 200.0)
        XCTAssertEqual(entry.unit, "lb")
    }

    func testWeightInKg() {
        let entry = WeightEntry(weight: 89.5, unit: "kg", date: Date())
        XCTAssertEqual(entry.weightInKg, 89.5)

        let lbEntry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        XCTAssertEqual(lbEntry.weightInKg, 89.5, accuracy: 0.1)
    }

    func testWeightInLb() {
        let entry = WeightEntry(weight: 89.5, unit: "kg", date: Date())
        XCTAssertEqual(entry.weightInLb, 197.3, accuracy: 0.1)

        let lbEntry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        XCTAssertEqual(lbEntry.weightInLb, 197.4)
    }

    func testUpdatedAtAutoSets() {
        let entry = WeightEntry(weight: 197.4)
        XCTAssertNotNil(entry.updatedAt)
        XCTAssertNotNil(entry.createdAt)
    }

    func testDateStrippedToMidnight() {
        let now = Date()
        let entry = WeightEntry(weight: 197.4, date: now)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: entry.date)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }
}
