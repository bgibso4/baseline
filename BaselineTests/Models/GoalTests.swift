import XCTest
import SwiftData
@testable import Baseline

final class GoalTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, Scan.self, Baseline.Measurement.self, SyncState.self, Goal.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - testCreateActiveGoal

    func testCreateActiveGoal() {
        let goal = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        context.insert(goal)
        try! context.save()

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.count, 1)
        let fetched = goals.first!
        XCTAssertEqual(fetched.metric, "weight")
        XCTAssertEqual(fetched.targetValue, 180.0)
        XCTAssertEqual(fetched.startValue, 200.0)
        XCTAssertEqual(fetched.status, .active)
        XCTAssertNil(fetched.targetDate)
        XCTAssertNil(fetched.completedDate)
    }

    // MARK: - testCreateGoalWithDate

    func testCreateGoalWithDate() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 90, to: Date())!
        let afternoonDate = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: futureDate)!
        let goal = Goal(metric: "bodyFat", targetValue: 15.0, startValue: 20.0, targetDate: afternoonDate)

        XCTAssertNotNil(goal.targetDate)
        // Should be normalized to start of day
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: goal.targetDate!)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: - testGoalStatusTransitions

    func testGoalStatusTransitions() {
        let goal = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertEqual(goal.status, .active)

        goal.status = .completed
        XCTAssertEqual(goal.status, .completed)

        goal.status = .abandoned
        XCTAssertEqual(goal.status, .abandoned)

        goal.status = .active
        XCTAssertEqual(goal.status, .active)
    }

    // MARK: - testDirectionInference

    func testDirectionInference() {
        let cuttingGoal = Goal(metric: "weight", targetValue: 170.0, startValue: 200.0)
        XCTAssertTrue(cuttingGoal.isDecreasing)

        let bulkingGoal = Goal(metric: "weight", targetValue: 210.0, startValue: 190.0)
        XCTAssertFalse(bulkingGoal.isDecreasing)
    }

    // MARK: - testProgressCalculation (cutting)

    func testProgressCalculation() {
        // Cutting: start=200, target=180, range=20
        let goal = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0)

        // At start: 0%
        XCTAssertEqual(goal.progress(currentValue: 200.0), 0.0, accuracy: 0.001)

        // Moved 4 lbs of 20: 20%
        XCTAssertEqual(goal.progress(currentValue: 196.0), 0.2, accuracy: 0.001)

        // At target: 100%
        XCTAssertEqual(goal.progress(currentValue: 180.0), 1.0, accuracy: 0.001)

        // Overshot — clamped to 100%
        XCTAssertEqual(goal.progress(currentValue: 175.0), 1.0, accuracy: 0.001)
    }

    // MARK: - testProgressCalculationBulk

    func testProgressCalculationBulk() {
        // Bulking: start=190, target=210, range=20
        let goal = Goal(metric: "weight", targetValue: 210.0, startValue: 190.0)

        // At start: 0%
        XCTAssertEqual(goal.progress(currentValue: 190.0), 0.0, accuracy: 0.001)

        // Moved 10 lbs of 20: 50%
        XCTAssertEqual(goal.progress(currentValue: 200.0), 0.5, accuracy: 0.001)

        // At target: 100%
        XCTAssertEqual(goal.progress(currentValue: 210.0), 1.0, accuracy: 0.001)

        // Overshot — clamped to 100%
        XCTAssertEqual(goal.progress(currentValue: 215.0), 1.0, accuracy: 0.001)
    }

    // MARK: - testGoalReachedDetection

    func testGoalReachedDetection() {
        // Cutting goal
        let cuttingGoal = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertFalse(cuttingGoal.isReached(currentValue: 185.0))
        XCTAssertTrue(cuttingGoal.isReached(currentValue: 180.0))
        XCTAssertTrue(cuttingGoal.isReached(currentValue: 175.0))

        // Bulking goal
        let bulkingGoal = Goal(metric: "weight", targetValue: 210.0, startValue: 190.0)
        XCTAssertFalse(bulkingGoal.isReached(currentValue: 205.0))
        XCTAssertTrue(bulkingGoal.isReached(currentValue: 210.0))
        XCTAssertTrue(bulkingGoal.isReached(currentValue: 215.0))
    }

    // MARK: - testRemainingValue

    func testRemainingValue() {
        // Cutting: start=200, target=180
        let cuttingGoal = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertEqual(cuttingGoal.remaining(currentValue: 190.0), 10.0, accuracy: 0.001)
        XCTAssertEqual(cuttingGoal.remaining(currentValue: 185.0), 5.0, accuracy: 0.001)
        // Reached — remaining is 0
        XCTAssertEqual(cuttingGoal.remaining(currentValue: 180.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(cuttingGoal.remaining(currentValue: 175.0), 0.0, accuracy: 0.001)
    }

    // MARK: - testDaysRemaining

    func testDaysRemaining() {
        // No target date
        let noDate = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertNil(noDate.daysRemaining)

        // Future date: 30 days from now
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let withDate = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0, targetDate: futureDate)
        let days = withDate.daysRemaining
        XCTAssertNotNil(days)
        // Allow 1 day of tolerance for test running near midnight
        XCTAssertTrue(abs(days! - 30) <= 1, "Expected daysRemaining ~30, got \(days!)")

        // Past date — should return 0
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let pastGoal = Goal(metric: "weight", targetValue: 180.0, startValue: 200.0, targetDate: pastDate)
        XCTAssertEqual(pastGoal.daysRemaining, 0)
    }
}

// MARK: - GoalViewModelTests

final class GoalViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var viewModel: GoalViewModel!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, Scan.self, Baseline.Measurement.self, SyncState.self, Goal.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        viewModel = GoalViewModel(modelContext: context)
    }

    override func tearDown() {
        viewModel = nil
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - testActiveGoalNilByDefault

    func testActiveGoalNilByDefault() {
        XCTAssertNil(viewModel.activeGoal)
    }

    // MARK: - testSetGoalCreatesActiveGoal

    func testSetGoalCreatesActiveGoal() {
        viewModel.setGoal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertNotNil(viewModel.activeGoal)
        XCTAssertEqual(viewModel.activeGoal?.metric, "weight")
        XCTAssertEqual(viewModel.activeGoal?.targetValue, 180.0)
        XCTAssertEqual(viewModel.activeGoal?.startValue, 200.0)
        XCTAssertEqual(viewModel.activeGoal?.status, .active)
    }

    // MARK: - testSetGoalWithDate

    func testSetGoalWithDate() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        viewModel.setGoal(metric: "bodyFat", targetValue: 15.0, startValue: 20.0, targetDate: futureDate)
        XCTAssertNotNil(viewModel.activeGoal)
        XCTAssertNotNil(viewModel.activeGoal?.targetDate)
        // Should be normalized to start of day
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: viewModel.activeGoal!.targetDate!)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
    }

    // MARK: - testCannotSetGoalWhileOneIsActive

    func testCannotSetGoalWhileOneIsActive() {
        viewModel.setGoal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        let firstGoal = viewModel.activeGoal

        viewModel.setGoal(metric: "bodyFat", targetValue: 15.0, startValue: 20.0)

        // Second call should be ignored — first goal stays
        XCTAssertEqual(viewModel.activeGoal?.metric, "weight")
        XCTAssertEqual(viewModel.activeGoal?.id, firstGoal?.id)

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.count, 1)
    }

    // MARK: - testCompleteGoal

    func testCompleteGoal() {
        viewModel.setGoal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertNotNil(viewModel.activeGoal)

        viewModel.completeGoal()
        XCTAssertNil(viewModel.activeGoal)

        // Goal should persist in DB with completed status
        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.status, .completed)
        XCTAssertNotNil(goals.first?.completedDate)
    }

    // MARK: - testAbandonGoal

    func testAbandonGoal() {
        viewModel.setGoal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertNotNil(viewModel.activeGoal)

        viewModel.abandonGoal()
        XCTAssertNil(viewModel.activeGoal)

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.status, .abandoned)
        XCTAssertNotNil(goals.first?.completedDate)
    }

    // MARK: - testCheckCompletionReturnsTrueWhenReached

    func testCheckCompletionReturnsTrueWhenReached() {
        // Cutting goal: target 180, start 200
        viewModel.setGoal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertNotNil(viewModel.activeGoal)

        // currentValue reaches target
        let result = viewModel.checkCompletion(metricKey: "weight", currentValue: 179.5)
        XCTAssertTrue(result)
        XCTAssertNil(viewModel.activeGoal)

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.first?.status, .completed)
    }

    // MARK: - testCheckCompletionIgnoresWrongMetric

    func testCheckCompletionIgnoresWrongMetric() {
        viewModel.setGoal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertNotNil(viewModel.activeGoal)

        // Wrong metric key — goal should remain active even if value would be reached
        let result = viewModel.checkCompletion(metricKey: "bodyFat", currentValue: 170.0)
        XCTAssertFalse(result)
        XCTAssertNotNil(viewModel.activeGoal)
        XCTAssertEqual(viewModel.activeGoal?.status, .active)
    }

    // MARK: - testUpdateGoal

    func testUpdateGoal() {
        viewModel.setGoal(metric: "weight", targetValue: 180.0, startValue: 200.0)
        XCTAssertNotNil(viewModel.activeGoal)

        let newDate = Calendar.current.date(byAdding: .day, value: 90, to: Date())!
        viewModel.updateGoal(targetValue: 175.0, targetDate: newDate)

        XCTAssertEqual(viewModel.activeGoal?.targetValue, 175.0)
        XCTAssertNotNil(viewModel.activeGoal?.targetDate)

        // Verify persisted
        viewModel.refresh()
        XCTAssertEqual(viewModel.activeGoal?.targetValue, 175.0)
    }
}
