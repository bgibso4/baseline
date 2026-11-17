import SwiftData
import XCTest
@testable import Baseline

/// Proves the next real schema change can migrate a V1 store on disk without losing records.
/// Uses test-only `TestSchemaV2` (new attribute, renamed attribute, new model), not production schemas.
final class SchemaMigrationTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testV1StoreMigratesToV2WithAllRecordsIntact() throws {
        let day1 = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let day2 = Date(timeIntervalSinceReferenceDate: 700_086_400)
        let storeURL = directory.appendingPathComponent("Baseline.store")

        // Seed with V1; the container is released at the end of this scope.
        let weightIDs: [UUID]
        let goalID: UUID
        let scanID: UUID
        do {
            let container = try makeContainer(BaselineSchemaV1.self, plan: nil, url: storeURL)
            let context = ModelContext(container)
            let first = BaselineSchemaV1.WeightEntry(weight: 180.5, unit: "lb", date: day1, notes: "morning")
            let second = BaselineSchemaV1.WeightEntry(weight: 82.1, unit: "kg", date: day2)
            let goal = BaselineSchemaV1.Goal(metric: "weight", targetValue: 170, startValue: 180.5)
            let scan = BaselineSchemaV1.Scan(
                date: day1, type: .inBody, source: .manual, payload: Data([1, 2, 3]), notes: "scan note"
            )
            context.insert(first)
            context.insert(second)
            context.insert(BaselineSchemaV1.Measurement(date: day1, type: .waist, valueCm: 81.3))
            context.insert(goal)
            context.insert(scan)
            try context.save()
            weightIDs = [first.id, second.id]
            goalID = goal.id
            scanID = scan.id
        }

        let container = try makeContainer(TestSchemaV2.self, plan: TestMigrationPlanV1toV2.self, url: storeURL)
        let context = ModelContext(container)

        let weights = try context.fetch(FetchDescriptor<TestSchemaV2.WeightEntry>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(weights.count, 2)
        XCTAssertEqual(weights.map(\.id), weightIDs)
        XCTAssertEqual(weights.map(\.weight), [180.5, 82.1])
        XCTAssertEqual(weights.map(\.unit), ["lb", "kg"])
        XCTAssertEqual(weights.map(\.date), [day1, day2].map { Calendar.current.startOfDay(for: $0) })
        XCTAssertEqual(weights.map(\.notes), ["morning", nil])
        XCTAssertEqual(weights.map(\.bodyFatPercent), [nil, nil])

        let measurements = try context.fetch(FetchDescriptor<TestSchemaV2.Measurement>())
        XCTAssertEqual(measurements.count, 1)
        XCTAssertEqual(measurements.first?.valueInCm, 81.3)

        let goals = try context.fetch(FetchDescriptor<BaselineSchemaV1.Goal>())
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.id, goalID)
        XCTAssertEqual(goals.first?.metric, "weight")
        XCTAssertEqual(goals.first?.targetValue, 170)
        XCTAssertEqual(goals.first?.startValue, 180.5)

        let scans = try context.fetch(FetchDescriptor<BaselineSchemaV1.Scan>())
        XCTAssertEqual(scans.count, 1)
        XCTAssertEqual(scans.first?.id, scanID)
        XCTAssertEqual(scans.first?.type, "inBody")
        XCTAssertEqual(scans.first?.source, "manual")
        XCTAssertEqual(scans.first?.payloadData, Data([1, 2, 3]))
        XCTAssertEqual(scans.first?.notes, "scan note")

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TestSchemaV2.ProgressPhoto>()), 0)
        context.insert(TestSchemaV2.ProgressPhoto(imageData: Data([9])))
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TestSchemaV2.ProgressPhoto>()), 1)
    }

    private func makeContainer(
        _ schema: any VersionedSchema.Type,
        plan: (any SchemaMigrationPlan.Type)?,
        url: URL
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(versionedSchema: schema), url: url, cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: Schema(versionedSchema: schema), migrationPlan: plan, configurations: [configuration]
        )
    }
}
