# Goal Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users set a target for any trackable metric with an optional deadline, see progress on the Trends chart and Now screen, and get notified when they reach it.

**Architecture:** SwiftData `Goal` model synced via CloudKit. `GoalViewModel` manages the active goal lifecycle. Goal card renders below the stats row on TrendsView. NowView stats card swaps to goal context when active. Completion auto-detects after weigh-in/scan saves.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Charts

**Spec:** `docs/superpowers/specs/2026-04-13-goal-tracking-design.md`
**Mockups:** `docs/mockups/goal-tracking-design.html`

---

## File Structure

| File | Responsibility |
|------|---------------|
| Create: `Baseline/Models/Goal.swift` | SwiftData model + GoalStatus enum |
| Create: `Baseline/ViewModels/GoalViewModel.swift` | Active goal lifecycle, progress calculations, completion detection |
| Create: `Baseline/Views/Trends/GoalCard.swift` | Goal card below stats (empty state + active state) |
| Create: `Baseline/Views/Trends/SetGoalSheet.swift` | Set/edit goal sheet |
| Create: `Baseline/Views/Trends/GoalManageSheet.swift` | ··· menu action sheet (edit/complete/abandon) |
| Create: `Baseline/Views/Components/GoalReachedOverlay.swift` | Celebration modal |
| Modify: `Baseline/Views/Trends/TrendsView.swift` | Insert goal card + goal line on chart |
| Modify: `Baseline/Views/Now/NowView.swift` | Stats card swap when goal active |
| Modify: `Baseline/BaselineApp.swift` | Register Goal in SwiftData schema |
| Create: `BaselineTests/Models/GoalTests.swift` | Model + view model unit tests |

---

### Task 1: Goal Data Model

**Files:**
- Create: `Baseline/Models/Goal.swift`
- Modify: `Baseline/BaselineApp.swift:22-48`
- Test: `BaselineTests/Models/GoalTests.swift`

- [ ] **Step 1: Write the failing test**

Create `BaselineTests/Models/GoalTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class GoalTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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

    func testCreateActiveGoal() {
        let goal = Goal(
            metric: "weight",
            targetValue: 185.0,
            startValue: 200.0
        )
        context.insert(goal)
        try! context.save()

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.metric, "weight")
        XCTAssertEqual(goals.first?.targetValue, 185.0)
        XCTAssertEqual(goals.first?.startValue, 200.0)
        XCTAssertEqual(goals.first?.goalStatus, .active)
        XCTAssertNil(goals.first?.targetDate)
        XCTAssertNil(goals.first?.completedDate)
    }

    func testCreateGoalWithDate() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let goal = Goal(
            metric: "bodyFatPct",
            targetValue: 15.0,
            startValue: 20.0,
            targetDate: futureDate
        )
        context.insert(goal)
        try! context.save()

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.first?.targetDate, Calendar.current.startOfDay(for: futureDate))
    }

    func testGoalStatusTransitions() {
        let goal = Goal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertEqual(goal.goalStatus, .active)

        goal.status = GoalStatus.completed.rawValue
        goal.completedDate = Date()
        XCTAssertEqual(goal.goalStatus, .completed)

        let goal2 = Goal(metric: "weight", targetValue: 175.0, startValue: 190.0)
        goal2.status = GoalStatus.abandoned.rawValue
        XCTAssertEqual(goal2.goalStatus, .abandoned)
    }

    func testDirectionInference() {
        let cut = Goal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertTrue(cut.isCutting) // target < start

        let bulk = Goal(metric: "weight", targetValue: 220.0, startValue: 200.0)
        XCTAssertFalse(bulk.isCutting) // target > start
    }

    func testProgressCalculation() {
        let goal = Goal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        // Started at 200, target 185, total distance = 15
        // At 197: moved 3 of 15 = 20%
        XCTAssertEqual(goal.progress(currentValue: 197.0), 0.2, accuracy: 0.01)
        // At 185: moved 15 of 15 = 100%
        XCTAssertEqual(goal.progress(currentValue: 185.0), 1.0, accuracy: 0.01)
        // At 200: moved 0 of 15 = 0%
        XCTAssertEqual(goal.progress(currentValue: 200.0), 0.0, accuracy: 0.01)
        // Overshoot: at 180 = still clamped to 1.0
        XCTAssertEqual(goal.progress(currentValue: 180.0), 1.0, accuracy: 0.01)
    }

    func testProgressCalculationBulk() {
        let goal = Goal(metric: "skeletalMuscle", targetValue: 50.0, startValue: 40.0)
        XCTAssertEqual(goal.progress(currentValue: 42.0), 0.2, accuracy: 0.01)
        XCTAssertEqual(goal.progress(currentValue: 50.0), 1.0, accuracy: 0.01)
    }

    func testGoalReachedDetection() {
        let cut = Goal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertFalse(cut.isReached(currentValue: 186.0))
        XCTAssertTrue(cut.isReached(currentValue: 185.0))
        XCTAssertTrue(cut.isReached(currentValue: 184.0))

        let bulk = Goal(metric: "skeletalMuscle", targetValue: 50.0, startValue: 40.0)
        XCTAssertFalse(bulk.isReached(currentValue: 49.0))
        XCTAssertTrue(bulk.isReached(currentValue: 50.0))
        XCTAssertTrue(bulk.isReached(currentValue: 51.0))
    }

    func testRemainingValue() {
        let goal = Goal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertEqual(goal.remaining(currentValue: 197.0), 12.0, accuracy: 0.01)
        XCTAssertEqual(goal.remaining(currentValue: 185.0), 0.0, accuracy: 0.01)
    }

    func testDaysRemaining() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let goal = Goal(metric: "weight", targetValue: 185.0, startValue: 200.0, targetDate: futureDate)
        let days = goal.daysRemaining
        XCTAssertNotNil(days)
        XCTAssertEqual(days!, 30, accuracy: 1)

        let noDateGoal = Goal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertNil(noDateGoal.daysRemaining)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:BaselineTests/GoalTests 2>&1 | grep -E '(error:|FAIL|BUILD)'`
Expected: Build error — `Goal` type not found.

- [ ] **Step 3: Write Goal model**

Create `Baseline/Models/Goal.swift`:

```swift
import Foundation
import SwiftData

enum GoalStatus: String, Codable {
    case active
    case completed
    case abandoned
}

@Model
final class Goal {
    var id: UUID = UUID()
    var metric: String = ""
    var targetValue: Double = 0.0
    var targetDate: Date?
    var startValue: Double = 0.0
    var startDate: Date = Date()
    var status: String = GoalStatus.active.rawValue
    var completedDate: Date?
    var createdAt: Date = Date()

    init(
        metric: String,
        targetValue: Double,
        startValue: Double,
        targetDate: Date? = nil
    ) {
        self.id = UUID()
        self.metric = metric
        self.targetValue = targetValue
        self.startValue = startValue
        self.startDate = Date()
        self.targetDate = targetDate.map { Calendar.current.startOfDay(for: $0) }
        self.status = GoalStatus.active.rawValue
        self.createdAt = Date()
    }

    var goalStatus: GoalStatus {
        GoalStatus(rawValue: status) ?? .active
    }

    /// True when target < start (losing weight, cutting body fat, etc.)
    var isCutting: Bool {
        targetValue < startValue
    }

    /// Progress from 0.0 to 1.0 based on current value relative to start → target.
    func progress(currentValue: Double) -> Double {
        let totalDistance = abs(targetValue - startValue)
        guard totalDistance > 0 else { return 1.0 }
        let moved = isCutting
            ? startValue - currentValue
            : currentValue - startValue
        return min(max(moved / totalDistance, 0.0), 1.0)
    }

    /// Absolute remaining distance to target.
    func remaining(currentValue: Double) -> Double {
        let diff = abs(currentValue - targetValue)
        return isReached(currentValue: currentValue) ? 0.0 : diff
    }

    /// Whether the current value has crossed or met the target.
    func isReached(currentValue: Double) -> Bool {
        if isCutting {
            return currentValue <= targetValue
        } else {
            return currentValue >= targetValue
        }
    }

    /// Days until target date, or nil if no date set.
    var daysRemaining: Int? {
        guard let targetDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: targetDate).day
        return max(days ?? 0, 0)
    }
}
```

- [ ] **Step 4: Register Goal in SwiftData schema**

In `Baseline/BaselineApp.swift`, add `Goal.self` to all three schema arrays:

```swift
// Line ~22: Add Goal.self to cloudSchema
let cloudSchema = Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self, Goal.self])

// Line ~41-46: Add Goal.self to fullSchema
let fullSchema = Schema([
    WeightEntry.self,
    Scan.self,
    BaselineMeasurement.self,
    SyncState.self,
    Goal.self,
])
```

- [ ] **Step 5: Add Goal.swift to Xcode project**

Add `Baseline/Models/Goal.swift` to the Xcode project's Models group and `BaselineTests/Models/GoalTests.swift` to the BaselineTests target.

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:BaselineTests/GoalTests 2>&1 | grep -E '(passed|failed|BUILD)'`
Expected: All 9 tests pass.

- [ ] **Step 7: Commit**

```bash
git add Baseline/Models/Goal.swift BaselineTests/Models/GoalTests.swift Baseline/BaselineApp.swift Baseline.xcodeproj/project.pbxproj
git commit -m "feat: add Goal SwiftData model with status, progress, and completion detection"
```

---

### Task 2: GoalViewModel

**Files:**
- Create: `Baseline/ViewModels/GoalViewModel.swift`
- Test: `BaselineTests/Models/GoalTests.swift` (append)

- [ ] **Step 1: Write failing tests**

Append to `BaselineTests/Models/GoalTests.swift`:

```swift
// MARK: - GoalViewModel Tests

final class GoalViewModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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

    func testActiveGoalNilByDefault() {
        let vm = GoalViewModel(modelContext: context)
        XCTAssertNil(vm.activeGoal)
    }

    func testSetGoalCreatesActiveGoal() {
        let vm = GoalViewModel(modelContext: context)
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertNotNil(vm.activeGoal)
        XCTAssertEqual(vm.activeGoal?.metric, "weight")
        XCTAssertEqual(vm.activeGoal?.targetValue, 185.0)
        XCTAssertEqual(vm.activeGoal?.goalStatus, .active)
    }

    func testSetGoalWithDate() {
        let vm = GoalViewModel(modelContext: context)
        let future = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0, targetDate: future)
        XCTAssertNotNil(vm.activeGoal?.targetDate)
    }

    func testCannotSetGoalWhileOneIsActive() {
        let vm = GoalViewModel(modelContext: context)
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0)

        // Attempt to set another — should be ignored
        vm.setGoal(metric: "bodyFatPct", targetValue: 15.0, startValue: 20.0)
        XCTAssertEqual(vm.activeGoal?.metric, "weight") // still the first one

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.count, 1) // only one goal created
    }

    func testCompleteGoal() {
        let vm = GoalViewModel(modelContext: context)
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        vm.completeGoal()
        XCTAssertNil(vm.activeGoal)

        // Should still exist in DB as completed
        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.goalStatus, .completed)
        XCTAssertNotNil(goals.first?.completedDate)
    }

    func testAbandonGoal() {
        let vm = GoalViewModel(modelContext: context)
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        vm.abandonGoal()
        XCTAssertNil(vm.activeGoal)

        let descriptor = FetchDescriptor<Goal>()
        let goals = try! context.fetch(descriptor)
        XCTAssertEqual(goals.first?.goalStatus, .abandoned)
    }

    func testCheckCompletionReturnsTrueWhenReached() {
        let vm = GoalViewModel(modelContext: context)
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertFalse(vm.checkCompletion(metricKey: "weight", currentValue: 190.0))
        XCTAssertTrue(vm.checkCompletion(metricKey: "weight", currentValue: 184.0))
        // After completion, goal should be marked completed
        XCTAssertNil(vm.activeGoal)
    }

    func testCheckCompletionIgnoresWrongMetric() {
        let vm = GoalViewModel(modelContext: context)
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        XCTAssertFalse(vm.checkCompletion(metricKey: "bodyFatPct", currentValue: 10.0))
        XCTAssertNotNil(vm.activeGoal) // still active
    }

    func testUpdateGoal() {
        let vm = GoalViewModel(modelContext: context)
        vm.setGoal(metric: "weight", targetValue: 185.0, startValue: 200.0)
        vm.updateGoal(targetValue: 180.0, targetDate: nil)
        XCTAssertEqual(vm.activeGoal?.targetValue, 180.0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:BaselineTests/GoalViewModelTests 2>&1 | grep -E '(error:|FAIL|BUILD)'`
Expected: Build error — `GoalViewModel` not found.

- [ ] **Step 3: Implement GoalViewModel**

Create `Baseline/ViewModels/GoalViewModel.swift`:

```swift
import Foundation
import SwiftData

@Observable
class GoalViewModel {

    private let modelContext: ModelContext

    var activeGoal: Goal?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        let activeStatus = GoalStatus.active.rawValue
        var descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.status == activeStatus }
        )
        descriptor.fetchLimit = 1
        activeGoal = try? modelContext.fetch(descriptor).first
    }

    func setGoal(metric: String, targetValue: Double, startValue: Double, targetDate: Date? = nil) {
        // Cannot set a new goal while one is active — must complete or abandon first
        guard activeGoal == nil else { return }

        let goal = Goal(
            metric: metric,
            targetValue: targetValue,
            startValue: startValue,
            targetDate: targetDate
        )
        modelContext.insert(goal)
        try? modelContext.save()
        activeGoal = goal
    }

    func updateGoal(targetValue: Double, targetDate: Date?) {
        guard let goal = activeGoal else { return }
        goal.targetValue = targetValue
        goal.targetDate = targetDate.map { Calendar.current.startOfDay(for: $0) }
        try? modelContext.save()
    }

    func completeGoal() {
        guard let goal = activeGoal else { return }
        goal.status = GoalStatus.completed.rawValue
        goal.completedDate = Date()
        try? modelContext.save()
        activeGoal = nil
    }

    func abandonGoal() {
        guard let goal = activeGoal else { return }
        goal.status = GoalStatus.abandoned.rawValue
        goal.completedDate = Date()
        try? modelContext.save()
        activeGoal = nil
    }

    /// Check if the active goal is reached. Returns true (and marks completed) if so.
    /// Only triggers for the matching metric.
    func checkCompletion(metricKey: String, currentValue: Double) -> Bool {
        guard let goal = activeGoal,
              goal.metric == metricKey,
              goal.isReached(currentValue: currentValue) else {
            return false
        }
        completeGoal()
        return true
    }
}
```

- [ ] **Step 4: Add to Xcode project and run tests**

Add `GoalViewModel.swift` to the project. Run:
`xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:BaselineTests/GoalViewModelTests 2>&1 | grep -E '(passed|failed)'`
Expected: All 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/GoalViewModel.swift BaselineTests/Models/GoalTests.swift Baseline.xcodeproj/project.pbxproj
git commit -m "feat: add GoalViewModel with lifecycle management and completion detection"
```

---

### Task 3: Goal Card on Trends Screen

**Files:**
- Create: `Baseline/Views/Trends/GoalCard.swift`
- Modify: `Baseline/Views/Trends/TrendsView.swift:341-343`

- [ ] **Step 1: Create GoalCard**

Create `Baseline/Views/Trends/GoalCard.swift`:

```swift
import SwiftUI

struct GoalCard: View {
    let goal: Goal?
    let currentValue: Double?
    let unit: String
    let onSetGoal: () -> Void
    let onManageGoal: () -> Void

    var body: some View {
        if let goal, let currentValue {
            activeCard(goal: goal, currentValue: currentValue)
        } else {
            emptyCard
        }
    }

    // MARK: - Empty State

    private var emptyCard: some View {
        Button(action: onSetGoal) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CadreColors.cardElevated)
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CadreColors.accent)
                }
                Text("Set a goal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(CadreColors.divider, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active State

    private func activeCard(goal: Goal, currentValue: Double) -> some View {
        VStack(spacing: 0) {
            // Header: GOAL label + optional date + ··· menu
            HStack {
                HStack(spacing: 6) {
                    Text("GOAL")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.accent)
                    if let days = goal.daysRemaining {
                        Text("·")
                            .foregroundStyle(CadreColors.textTertiary)
                        Text("by \(goalDateLabel(goal.targetDate!))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                }
                Spacer()
                Button(action: onManageGoal) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // Current → Target
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formatValue(currentValue))
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatValue(goal.targetValue))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(CadreColors.accent)
                        Text(unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                }
            }
            .padding(.bottom, 10)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CadreColors.cardElevated)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CadreColors.accent)
                        .frame(width: geo.size.width * goal.progress(currentValue: currentValue), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.bottom, 6)

            // Footer: remaining + percentage or days
            HStack {
                Text("\(formatValue(goal.remaining(currentValue: currentValue))) \(unit) to go")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                Spacer()
                if let days = goal.daysRemaining {
                    Text("\(days) day\(days == 1 ? "" : "s") left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                } else {
                    Text("\(Int(goal.progress(currentValue: currentValue) * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .padding(16)
        .background(CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(CadreColors.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func goalDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 2: Wire GoalCard into TrendsView**

In `Baseline/Views/Trends/TrendsView.swift`, add state and the goal card.

First, add properties near the top of TrendsView (after existing `@State` declarations):

```swift
@State private var goalVM: GoalViewModel?
@State private var showSetGoal = false
@State private var showManageGoal = false
```

In the `onAppear` block, initialize the goal VM:

```swift
goalVM = GoalViewModel(modelContext: modelContext)
```

After the `statsBlock` call (around line 341-343), insert:

```swift
            statsBlock(points: points, unit: unit)
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 12)

            // Goal card
            GoalCard(
                goal: goalVM?.activeGoal,
                currentValue: points.last?.value,
                unit: unit,
                onSetGoal: { showSetGoal = true },
                onManageGoal: { showManageGoal = true }
            )
            .padding(.horizontal, CadreSpacing.sheetHorizontal)
            .padding(.top, 10)
```

- [ ] **Step 3: Add to Xcode project, build to verify**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep BUILD`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Trends/GoalCard.swift Baseline/Views/Trends/TrendsView.swift Baseline.xcodeproj/project.pbxproj
git commit -m "feat: add GoalCard to Trends screen (empty + active states)"
```

---

### Task 4: Goal Line on Chart

**Files:**
- Modify: `Baseline/Views/Trends/TrendsView.swift` (chartBlock function)

- [ ] **Step 1: Add goal line to the chart**

In `Baseline/Views/Trends/TrendsView.swift`, find the `chartBlock` function (around line 474). Inside the `Chart { }` block, after the existing `LineMark`/`PointMark` entries, add a `RuleMark` for the goal line:

```swift
// Goal line — dotted horizontal at target value
if let goal = goalVM?.activeGoal,
   goal.metric == vm?.selectedMetric.rawValue {
    RuleMark(y: .value("Goal", goal.targetValue))
        .foregroundStyle(CadreColors.accent.opacity(0.5))
        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        .annotation(position: .trailing, alignment: .trailing) {
            Text(formatValue(goal.targetValue) + " " + (vm?.selectedMetric.unit ?? ""))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(CadreColors.accent)
                .padding(.leading, 4)
        }
}
```

Note: If TrendsView normalizes chart data (for dual-axis compare mode), the goal line should only render in single-metric mode (when `compareMode` is nil or disabled). Check if the chart uses raw values or normalized 0...1 values. If normalized, the goal line needs to be normalized too. For the default single-metric view, raw values are used, so `RuleMark(y: .value("Goal", goal.targetValue))` works directly.

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep BUILD`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Trends/TrendsView.swift
git commit -m "feat: add dotted goal line on Trends chart"
```

---

### Task 5: Set Goal Sheet

**Files:**
- Create: `Baseline/Views/Trends/SetGoalSheet.swift`
- Modify: `Baseline/Views/Trends/TrendsView.swift` (add sheet modifier)

- [ ] **Step 1: Create SetGoalSheet**

Create `Baseline/Views/Trends/SetGoalSheet.swift`:

```swift
import SwiftUI

struct SetGoalSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goalVM: GoalViewModel
    let defaultMetric: TrendMetric
    let currentValue: Double?
    var editingGoal: Goal? = nil

    @State private var selectedMetric: TrendMetric
    @State private var targetText: String = ""
    @State private var hasDate: Bool = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!

    init(goalVM: GoalViewModel, defaultMetric: TrendMetric, currentValue: Double?, editingGoal: Goal? = nil) {
        self.goalVM = goalVM
        self.defaultMetric = defaultMetric
        self.currentValue = currentValue
        self.editingGoal = editingGoal
        _selectedMetric = State(initialValue: editingGoal.flatMap { TrendMetric(rawValue: $0.metric) } ?? defaultMetric)
        _targetText = State(initialValue: editingGoal.map { String(format: "%.1f", $0.targetValue) } ?? "")
        _hasDate = State(initialValue: editingGoal?.targetDate != nil)
        _targetDate = State(initialValue: editingGoal?.targetDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
    }

    private var canSave: Bool {
        Double(targetText) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Metric picker
                            VStack(alignment: .leading, spacing: 6) {
                                sectionLabel("Metric")
                                Menu {
                                    ForEach(TrendMetric.allCases, id: \.self) { metric in
                                        Button(metric.rawValue) {
                                            selectedMetric = metric
                                        }
                                    }
                                } label: {
                                    fieldRow {
                                        Text(selectedMetric.rawValue)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(CadreColors.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(CadreColors.textTertiary)
                                    }
                                }
                            }

                            // Target value
                            VStack(alignment: .leading, spacing: 6) {
                                sectionLabel("Target")
                                fieldRow {
                                    TextField("", text: $targetText)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(CadreColors.textPrimary)
                                        .keyboardType(.decimalPad)
                                    Text(selectedMetric.unit)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(CadreColors.textSecondary)
                                }
                            }

                            // Target date (optional)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    sectionLabel("Target Date")
                                    Text("(optional)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(CadreColors.textTertiary.opacity(0.5))
                                }
                                Toggle(isOn: $hasDate.animation()) {
                                    if hasDate {
                                        DatePicker(
                                            "",
                                            selection: $targetDate,
                                            in: Date()...,
                                            displayedComponents: .date
                                        )
                                        .labelsHidden()
                                        .tint(CadreColors.accent)
                                    } else {
                                        Text("No deadline")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(CadreColors.textTertiary)
                                    }
                                }
                                .toggleStyle(.switch)
                                .tint(CadreColors.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(CadreColors.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                    }

                    // Save button
                    Button {
                        save()
                    } label: {
                        Text(editingGoal != nil ? "Update Goal" : "Set Goal")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(canSave ? CadreColors.accent : CadreColors.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle(editingGoal != nil ? "Edit Goal" : "Set Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .toolbarBackground(CadreColors.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(CadreColors.textTertiary)
    }

    private func fieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CadreColors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func save() {
        guard let target = Double(targetText) else { return }
        let date = hasDate ? targetDate : nil
        let start = currentValue ?? 0

        if editingGoal != nil {
            goalVM.updateGoal(targetValue: target, targetDate: date)
        } else {
            goalVM.setGoal(
                metric: selectedMetric.rawValue,
                targetValue: target,
                startValue: start,
                targetDate: date
            )
        }
        Haptics.success()
        dismiss()
    }
}
```

- [ ] **Step 2: Wire sheet into TrendsView**

In `Baseline/Views/Trends/TrendsView.swift`, add the sheet modifier (near other `.sheet` modifiers):

```swift
.sheet(isPresented: $showSetGoal) {
    if let goalVM {
        SetGoalSheet(
            goalVM: goalVM,
            defaultMetric: vm?.selectedMetric ?? .weight,
            currentValue: vm?.dataPoints.last?.value
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
```

- [ ] **Step 3: Add to Xcode project, build**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep BUILD`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Trends/SetGoalSheet.swift Baseline/Views/Trends/TrendsView.swift Baseline.xcodeproj/project.pbxproj
git commit -m "feat: add Set Goal sheet on Trends screen"
```

---

### Task 6: Goal Manage Sheet (··· menu)

**Files:**
- Create: `Baseline/Views/Trends/GoalManageSheet.swift`
- Modify: `Baseline/Views/Trends/TrendsView.swift` (add sheet modifier)

- [ ] **Step 1: Create GoalManageSheet**

Create `Baseline/Views/Trends/GoalManageSheet.swift`:

```swift
import SwiftUI

struct GoalManageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    let currentValue: Double
    let unit: String
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onAbandon: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(CadreColors.textTertiary)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            Text("GOAL")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(CadreColors.accent)
                .padding(.bottom, 8)

            // Current → Target
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formatValue(currentValue))
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatValue(goal.targetValue))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(CadreColors.accent)
                        Text(unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 10)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CadreColors.cardElevated)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CadreColors.accent)
                        .frame(width: geo.size.width * goal.progress(currentValue: currentValue), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 22)
            .padding(.bottom, 6)

            // Footer
            HStack {
                Text("\(formatValue(goal.remaining(currentValue: currentValue))) \(unit) to go")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                Spacer()
                Text("Started \(startDateLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)

            // Action buttons
            VStack(spacing: 8) {
                Button {
                    dismiss()
                    onEdit()
                } label: {
                    Text("Edit Goal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CadreColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                    onComplete()
                } label: {
                    Text("Mark Complete")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.positive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CadreColors.cardElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(CadreColors.divider, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                    onAbandon()
                } label: {
                    Text("Abandon Goal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.negative)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        .background(CadreColors.card)
    }

    private var startDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: goal.startDate)
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
```

- [ ] **Step 2: Wire into TrendsView**

Add state for editing flow and the sheet modifier:

```swift
@State private var showEditGoal = false
```

Add the manage sheet:

```swift
.sheet(isPresented: $showManageGoal) {
    if let goalVM, let goal = goalVM.activeGoal {
        GoalManageSheet(
            goal: goal,
            currentValue: vm?.dataPoints.last?.value ?? 0,
            unit: vm?.selectedMetric.unit ?? "",
            onEdit: { showEditGoal = true },
            onComplete: { goalVM.completeGoal() },
            onAbandon: { goalVM.abandonGoal() }
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(CadreColors.card)
    }
}
.sheet(isPresented: $showEditGoal) {
    if let goalVM, let goal = goalVM.activeGoal {
        SetGoalSheet(
            goalVM: goalVM,
            defaultMetric: vm?.selectedMetric ?? .weight,
            currentValue: vm?.dataPoints.last?.value,
            editingGoal: goal
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
```

- [ ] **Step 3: Add to Xcode project, build**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep BUILD`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Trends/GoalManageSheet.swift Baseline/Views/Trends/TrendsView.swift Baseline.xcodeproj/project.pbxproj
git commit -m "feat: add goal manage sheet (edit/complete/abandon)"
```

---

### Task 7: Now Screen Stats Card Swap

**Files:**
- Modify: `Baseline/Views/Now/NowView.swift`

- [ ] **Step 1: Add goal state to NowView**

In `NowView.swift`, add properties:

```swift
@State private var goalVM: GoalViewModel?
@State private var showGoalStats = true  // true = show goal, false = show historical
```

Initialize in `onAppear`:

```swift
goalVM = GoalViewModel(modelContext: modelContext)
```

- [ ] **Step 2: Create goal stats card variant**

Add a new function in NowView:

```swift
private var goalStatsCard: some View {
    guard let goal = goalVM?.activeGoal else { return AnyView(statsCard) }

    let current = vm?.todayEntry.map { displayWeight(for: $0) }
        ?? vm?.recentWeights.first.map { displayWeight(for: $0) }
        ?? 0
    let unit = vm?.unit ?? "lb"

    return AnyView(
        HStack(spacing: 1) {
            statCell(label: "CURRENT", value: current, unit: unit)
            VStack(spacing: 4) {
                Text("TARGET")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(CadreColors.accent)
                Text(formatGoalValue(goal.targetValue))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(CadreColors.accent)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(CadreColors.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CadreColors.card)
            VStack(spacing: 4) {
                Text("TO GO")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(CadreColors.textTertiary)
                Text(formatGoalValue(goal.remaining(currentValue: current)))
                    .font(.system(size: 18, weight: .bold))
                    .contentTransition(.numericText())
                if let days = goal.daysRemaining {
                    Text("\(days) days left")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                } else {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CadreColors.card)
        }
        .background(CadreColors.divider)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { showGoalStats.toggle() }
    )
}

private func formatGoalValue(_ value: Double) -> String {
    if value == value.rounded() && value >= 10 {
        return String(format: "%.0f", value)
    }
    return String(format: "%.1f", value)
}
```

- [ ] **Step 3: Replace stats card usage**

Find where `statsCard` is used in NowView's body and wrap it:

```swift
// Replace direct statsCard reference with:
if goalVM?.activeGoal != nil && showGoalStats {
    goalStatsCard
} else {
    statsCard
}
```

Add tap gesture to the regular `statsCard` too (if goal exists, tapping toggles):

```swift
.onTapGesture {
    if goalVM?.activeGoal != nil { showGoalStats.toggle() }
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep BUILD`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/Views/Now/NowView.swift
git commit -m "feat: Now screen stats card swaps to goal context when active"
```

---

### Task 8: Goal Completion Detection + Celebration

**Files:**
- Create: `Baseline/Views/Components/GoalReachedOverlay.swift`
- Modify: `Baseline/ViewModels/WeighInViewModel.swift`
- Modify: `Baseline/ViewModels/ScanEntryViewModel.swift`
- Modify: `Baseline/Views/Now/NowView.swift`
- Modify: `Baseline/Views/Body/ScanEntryFlow.swift`

- [ ] **Step 1: Create GoalReachedOverlay**

Create `Baseline/Views/Components/GoalReachedOverlay.swift`:

```swift
import SwiftUI

struct GoalReachedOverlay: View {
    let targetValue: Double
    let startValue: Double
    let unit: String
    let startDate: Date
    let onNewGoal: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("🎯")
                    .font(.system(size: 48))
                    .padding(.bottom, 16)

                Text("Goal Reached!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .padding(.bottom, 6)

                HStack(spacing: 4) {
                    Text("Target:")
                        .foregroundStyle(CadreColors.textSecondary)
                    Text("\(formatValue(targetValue)) \(unit)")
                        .foregroundStyle(CadreColors.accent)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 13))
                .padding(.bottom, 4)

                Text("Started at \(formatValue(startValue)) \(unit) on \(dateLabel)")
                    .font(.system(size: 13))
                    .foregroundStyle(CadreColors.textSecondary)
                    .padding(.bottom, 24)

                Button(action: onNewGoal) {
                    Text("Set New Goal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CadreColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.bottom, 10)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                        .padding(.vertical, 10)
                }
            }
            .padding(28)
            .background(CadreColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(CadreColors.divider, lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: startDate)
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
```

- [ ] **Step 2: Add completion check to WeighInViewModel**

In `Baseline/ViewModels/WeighInViewModel.swift`, modify the `save()` function. After `try? modelContext.save()` (around line 60), add a return value or callback for goal completion:

Add a property to WeighInViewModel:

```swift
var goalReached: Bool = false
private var reachedGoalInfo: (target: Double, start: Double, startDate: Date)?

var reachedGoal: (target: Double, start: Double, startDate: Date)? { reachedGoalInfo }
```

At the end of the `save()` function, after the HealthKit call:

```swift
// Check goal completion
let goalVM = GoalViewModel(modelContext: modelContext)
let weightInStored = unit == "kg" ? currentWeight : UnitConversion.lbToKg(currentWeight)
if goalVM.checkCompletion(metricKey: "weight", currentValue: currentWeight) {
    // Store goal info for celebration overlay
    reachedGoalInfo = (target: goalVM.activeGoal?.targetValue ?? currentWeight, start: goalVM.activeGoal?.startValue ?? currentWeight, startDate: goalVM.activeGoal?.startDate ?? Date())
    goalReached = true
}
```

Note: The completion check uses the display unit value (lb or kg) since that's what the user set the goal in. The `GoalViewModel.checkCompletion` compares against the stored goal's `targetValue`.

- [ ] **Step 3: Wire celebration overlay into NowView**

In `Baseline/Views/Now/NowView.swift`, add state:

```swift
@State private var showGoalReached = false
@State private var reachedGoalTarget: Double = 0
@State private var reachedGoalStart: Double = 0
@State private var reachedGoalStartDate: Date = Date()
```

In the WeighInSheet's `onSave` callback, check for goal completion:

```swift
// After vm?.refresh(), check if the WeighInViewModel flagged goal reached
// This needs to be wired through the save callback
```

Add the overlay to NowView's body (inside the ZStack or as an overlay):

```swift
.overlay {
    if showGoalReached {
        GoalReachedOverlay(
            targetValue: reachedGoalTarget,
            startValue: reachedGoalStart,
            unit: vm?.unit ?? "lb",
            startDate: reachedGoalStartDate,
            onNewGoal: {
                showGoalReached = false
                // Could navigate to Trends tab to set new goal
            },
            onDismiss: {
                showGoalReached = false
            }
        )
    }
}
```

- [ ] **Step 4: Add to Xcode project, build**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep BUILD`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/Views/Components/GoalReachedOverlay.swift Baseline/ViewModels/WeighInViewModel.swift Baseline/Views/Now/NowView.swift Baseline.xcodeproj/project.pbxproj
git commit -m "feat: goal completion auto-detection with celebration overlay"
```

---

### Task 9: Final Integration & Testing

**Files:**
- All modified files
- Test: `BaselineTests/Models/GoalTests.swift`

- [ ] **Step 1: Run full test suite**

Run: `xcodebuild -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E '(passed|failed|BUILD)'`
Expected: All existing tests still pass. New GoalTests and GoalViewModelTests pass.

- [ ] **Step 2: Manual testing checklist**

On device, verify:
- [ ] Trends screen shows "Set a goal" dashed card when no goal exists
- [ ] Tapping "Set a goal" opens the Set Goal sheet
- [ ] Metric defaults to currently selected chart metric
- [ ] Can set a weight goal without a date → card shows with progress bar
- [ ] Can set a weight goal with a date → card shows "X days left"
- [ ] Dotted goal line appears on chart at target value
- [ ] ··· menu opens manage sheet with Edit/Complete/Abandon
- [ ] Edit opens pre-populated Set Goal sheet
- [ ] Mark Complete removes goal, card returns to "Set a goal"
- [ ] Abandon removes goal similarly
- [ ] Now screen shows goal stats (Current/Target/To Go) when goal active
- [ ] Tapping Now stats toggles between goal and historical view
- [ ] Logging a weight that crosses the target triggers celebration
- [ ] Celebration only fires once
- [ ] Goal line disappears when viewing a different metric
- [ ] Setting a new goal while one is active abandons the old one

- [ ] **Step 3: Commit final state**

```bash
git add -A
git commit -m "feat: goal tracking — complete implementation with chart overlay, stats swap, and completion detection"
```

---

## Summary

| Task | What it builds |
|------|---------------|
| 1 | Goal SwiftData model with progress/completion logic |
| 2 | GoalViewModel with lifecycle management |
| 3 | GoalCard on Trends (empty + active states) |
| 4 | Dotted goal line on chart |
| 5 | Set Goal sheet |
| 6 | Goal manage sheet (edit/complete/abandon) |
| 7 | Now screen stats card swap |
| 8 | Goal completion detection + celebration overlay |
| 9 | Integration testing |
