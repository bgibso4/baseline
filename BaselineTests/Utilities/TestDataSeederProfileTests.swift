#if DEBUG
import XCTest
import SwiftData
@testable import Baseline

final class TestDataSeederProfileTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([WeightEntry.self, Scan.self, Baseline.Measurement.self, Goal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private let refDate = Calendar.current.startOfDay(
        for: Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC
    )

    func testEmptyProfileInsertsNothing() throws {
        let context = try makeContext()
        TestDataSeeder.seed(profile: .empty, into: context, referenceDate: refDate)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Goal>()), 0)
    }

    func testPopulatedProfileSeedsKnownCounts() throws {
        let context = try makeContext()
        TestDataSeeder.seed(profile: .populated, into: context, referenceDate: refDate)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 90)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Scan>()), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Goal>()), 0)
    }

    func testGoalActiveProfileAddsActiveGoal() throws {
        let context = try makeContext()
        TestDataSeeder.seed(profile: .goalActive, into: context, referenceDate: refDate)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WeightEntry>()), 90)
        let goals = try context.fetch(FetchDescriptor<Goal>())
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.status, .active)
        XCTAssertEqual(goals.first?.metric, TrendMetric.weight.rawValue)
    }

    func testPopulatedIsDeterministicAcrossRuns() throws {
        let c1 = try makeContext(); TestDataSeeder.seed(profile: .populated, into: c1, referenceDate: refDate)
        let c2 = try makeContext(); TestDataSeeder.seed(profile: .populated, into: c2, referenceDate: refDate)
        let w1 = try c1.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)])).map(\.weight)
        let w2 = try c2.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)])).map(\.weight)
        XCTAssertEqual(w1, w2)
    }
}
#endif
