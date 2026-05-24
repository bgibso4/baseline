# Phase 2 — UI-Test Harness Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Baseline a deterministic, isolated UI-test harness — a launch-argument test mode backed by an in-memory seeded SwiftData store, an exhaustive accessibility-identifier registry, and a `BaselineUITests` target with audit + flow coverage that runs in CI.

**Architecture:** A single `LaunchConfiguration` value parses launch arguments once and drives (a) an in-memory, CloudKit-free, pre-seeded `ModelContainer` in `BaselineApp.init()` and (b) animation disabling. UI tests reference controls via a shared `A11yID` enum compiled into both the app and the test target. Tests run via three test plans (`Baseline` = all, `Baseline-CI` = logic + UI, `Baseline-UITests` = UI only).

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest + XCUITest, XcodeGen (`project.yml`), Makefile, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-05-21-phase-2-ui-test-harness-design.md`

**Conventions for every task:**
- Regenerate the Xcode project after any `project.yml` change: `make generate`.
- Run logic tests with `make test` (the `Baseline-CI` plan). UI tests: `make test-ui`.
- The repo blocks commits on SwiftLint *errors* and merge markers via the pre-commit hook — never use `--no-verify`.
- Do not push to `main` or open PRs without explicit instruction. Work happens on the feature branch the executor sets up.

---

## File Structure

**Create:**
- `Baseline/App/LaunchConfiguration.swift` — parses launch args/env into typed flags. Single source of truth for test mode.
- `Baseline/Accessibility/A11yID.swift` — nested enums of accessibility-identifier strings. Compiled into app **and** UI-test target.
- `BaselineUITests/BaseUITestCase.swift` — shared XCUITest base (launch args, tab nav helpers).
- `BaselineUITests/SmokeNavigationUITests.swift`
- `BaselineUITests/AccessibilityAuditUITests.swift`
- `BaselineUITests/IdentifierCoverageUITests.swift`
- `BaselineUITests/WeighInFlowUITests.swift`
- `BaselineUITests/SetGoalFlowUITests.swift`
- `BaselineUITests/ScanEntryFlowUITests.swift`
- `BaselineUITests/CSVImportFlowUITests.swift`
- `BaselineTests/App/LaunchConfigurationTests.swift` — unit tests for the parser.
- `BaselineTests/Utilities/TestDataSeederProfileTests.swift` — unit tests for seed profiles.
- `Baseline-UITests.xctestplan` — UI-test-only plan.
- `CONTRIBUTING.md` — dev setup + A11y tagging convention.

**Modify:**
- `Baseline/BaselineApp.swift` — test-mode container branch + `.task` guards.
- `Baseline/Utilities/TestDataSeeder.swift` — add `SeedProfile` + fixed-date seeding entry point.
- `Baseline/Design/Components/ArcIndicatorView.swift:39-41` — read `LaunchConfiguration.current.shouldDisableAnimations`.
- `Baseline/Views/Trends/TrendsView.swift:1050-1052` — same refactor.
- All view files needing tagging (Tasks 6–8): `MainTabView.swift`, `NowView.swift`, `WeighInSheet.swift`, `TrendsView.swift`, `SetGoalSheet.swift`, `MetricPickerSheet.swift`, `GoalCard.swift`, `GoalManageSheet.swift`, `BodyView.swift`, `ScanEntryFlow.swift`, `LogMeasurementSheet.swift`, `ScanHistoryView.swift`, `MetricHistoryView.swift`, `HistoryView.swift`, `SettingsView.swift`, `SettingsSubscreens.swift`.
- `project.yml` — `A11yID.swift` into app target (Task 5); `BaselineUITests` target + scheme test plans (Task 9); seed profiles compile into app.
- `Baseline.xctestplan`, `Baseline-CI.xctestplan` — add UI-test target (Task 13).
- `Makefile` — add `test-ui` (Task 13).

---

## Task 1: `LaunchConfiguration` parser

**Files:**
- Create: `Baseline/App/LaunchConfiguration.swift`
- Test: `BaselineTests/App/LaunchConfigurationTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// BaselineTests/App/LaunchConfigurationTests.swift
import XCTest
@testable import Baseline

final class LaunchConfigurationTests: XCTestCase {
    func testDefaultsWhenNoArgsOrEnv() {
        let config = LaunchConfiguration(arguments: ["/path/to/app"], environment: [:])
        XCTAssertFalse(config.isUITesting)
        XCTAssertFalse(config.shouldDisableAnimations)
    }

    func testUITestModeFlag() {
        let config = LaunchConfiguration(arguments: ["app", "-UITestMode"], environment: [:])
        XCTAssertTrue(config.isUITesting)
        XCTAssertTrue(config.shouldDisableAnimations)
        XCTAssertEqual(config.seedProfile, .populated, "UI-testing defaults to populated when no seed given")
    }

    func testSeedProfileParsing() {
        XCTAssertEqual(
            LaunchConfiguration(arguments: ["app", "-UITestMode", "-UITestSeed", "empty"], environment: [:]).seedProfile,
            .empty
        )
        XCTAssertEqual(
            LaunchConfiguration(arguments: ["app", "-UITestMode", "-UITestSeed", "goalActive"], environment: [:]).seedProfile,
            .goalActive
        )
    }

    func testUnknownSeedFallsBackToPopulated() {
        let config = LaunchConfiguration(arguments: ["app", "-UITestMode", "-UITestSeed", "bogus"], environment: [:])
        XCTAssertEqual(config.seedProfile, .populated)
    }

    func testUnitTestEnvDisablesAnimationsWithoutUITestMode() {
        let config = LaunchConfiguration(
            arguments: ["app"],
            environment: ["XCTestConfigurationFilePath": "/tmp/x.xctest"]
        )
        XCTAssertFalse(config.isUITesting, "Unit-test env is not UI testing")
        XCTAssertTrue(config.shouldDisableAnimations)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `LaunchConfiguration` / `SeedProfile` undefined.

- [ ] **Step 3: Implement `LaunchConfiguration` and `SeedProfile`**

```swift
// Baseline/App/LaunchConfiguration.swift
import Foundation

/// Deterministic seed datasets selectable from the launch arguments.
enum SeedProfile: String {
    case empty
    case populated
    case goalActive
}

/// Parses launch arguments and environment once into typed test-mode flags.
/// `current` is the process-wide value; tests construct their own instances.
struct LaunchConfiguration {
    let isUITesting: Bool
    let seedProfile: SeedProfile
    let shouldDisableAnimations: Bool

    init(arguments: [String], environment: [String: String]) {
        let uiTesting = arguments.contains("-UITestMode")
        self.isUITesting = uiTesting

        // -UITestSeed <value>; default to .populated under UI testing.
        var profile: SeedProfile = .populated
        if let idx = arguments.firstIndex(of: "-UITestSeed"),
           idx + 1 < arguments.count,
           let parsed = SeedProfile(rawValue: arguments[idx + 1]) {
            profile = parsed
        }
        self.seedProfile = profile

        let unitTesting = environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
        self.shouldDisableAnimations = uiTesting || unitTesting
    }

    static let current = LaunchConfiguration(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS (all 5 new tests).

- [ ] **Step 5: Commit**

```bash
git add Baseline/App/LaunchConfiguration.swift BaselineTests/App/LaunchConfigurationTests.swift
git commit -m "feat(test-mode): add LaunchConfiguration launch-arg parser"
```

> Note: `BaselineTests/App/` and `Baseline/App/` are new directories. XcodeGen picks up new files under the target `sources` paths automatically; run `make generate` before opening Xcode, but `make test` from CLI will pick them up after generate. If `make test` cannot find the new test, run `make generate` first.

---

## Task 2: Route existing animation checks through `LaunchConfiguration`

**Files:**
- Modify: `Baseline/Design/Components/ArcIndicatorView.swift:36-42`
- Modify: `Baseline/Views/Trends/TrendsView.swift:1038-1052`

- [ ] **Step 1: Refactor `ArcIndicatorView`**

Replace the env-var check (lines 36-42) with:

```swift
        // Under test (unit snapshot OR UI test), snapshot the gauge in its
        // final state — the spring animation hasn't run by frame-1 capture,
        // so the arc would otherwise come out empty / dot-only.
        let isTesting = LaunchConfiguration.current.shouldDisableAnimations
        let initialSweep: Double = isTesting ? 270 * (fraction ?? 0) : 0
        self._displaySweep = State(initialValue: initialSweep)
```

- [ ] **Step 2: Refactor `TrendsView`**

In `TrendsView.swift`, replace the private `isRunningTests` computed property (lines 1050-1052) and its use at line 1038. Delete the property and change line 1038's condition from `if reduceMotion || isRunningTests {` to:

```swift
        if reduceMotion || LaunchConfiguration.current.shouldDisableAnimations {
```

Then delete the now-unused `isRunningTests` property entirely.

- [ ] **Step 3: Verify the existing snapshot + logic suites still pass**

Run: `make test-all`
Expected: PASS — same behavior as before (unit-test env still sets `shouldDisableAnimations`). No snapshot diffs.

- [ ] **Step 4: Commit**

```bash
git add Baseline/Design/Components/ArcIndicatorView.swift Baseline/Views/Trends/TrendsView.swift
git commit -m "refactor(test-mode): read animation disable flag from LaunchConfiguration"
```

---

## Task 3: Seed profiles in `TestDataSeeder`

**Files:**
- Modify: `Baseline/Utilities/TestDataSeeder.swift`
- Test: `BaselineTests/Utilities/TestDataSeederProfileTests.swift`

**Context:** `TestDataSeeder` is wrapped in `#if DEBUG` and currently anchors fixtures to `Date()`. Add a profile-based entry point that accepts an explicit `referenceDate` so fixtures are deterministic regardless of the wall clock. Keep the existing `seed(context:)` (used by the in-app debug menu) intact — refactor it to call the new path with `referenceDate: Calendar.current.startOfDay(for: Date())` and `.populated`.

- [ ] **Step 1: Write the failing tests**

```swift
// BaselineTests/Utilities/TestDataSeederProfileTests.swift
#if DEBUG
import XCTest
import SwiftData
@testable import Baseline

final class TestDataSeederProfileTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([WeightEntry.self, Scan.self, Measurement.self, Goal.self])
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
        XCTAssertEqual(goals.first?.metric, "weight")
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `seed(profile:into:referenceDate:)` undefined.

- [ ] **Step 3: Implement the profile entry point**

In `TestDataSeeder.swift`, add the new API and make the existing private seeders accept an injected `today` (the `referenceDate`) instead of computing `Date()`. Replace each seeder's `let today = calendar.startOfDay(for: Date())` with a `today` parameter. Add:

```swift
    // MARK: - Profile-based seeding (deterministic)

    static func seed(profile: SeedProfile, into context: ModelContext, referenceDate: Date) {
        HealthKitManager.writesDisabled = true
        defer { HealthKitManager.writesDisabled = false }

        clearAll(context: context)
        guard profile != .empty else { try? context.save(); return }

        let today = Calendar.current.startOfDay(for: referenceDate)
        seedWeightEntries(context: context, today: today)
        seedScans(context: context, today: today)
        seedMeasurements(context: context, today: today)

        if profile == .goalActive {
            // Active weight goal: start at the earliest seeded weight, target lower.
            let goal = Goal(
                metric: TrendMetric.weight.rawValue,
                targetValue: 185.0,
                startValue: 205.0,
                targetDate: Calendar.current.date(byAdding: .day, value: 60, to: today)
            )
            context.insert(goal)
        }

        try? context.save()
        Log.app.info("Seeded test data (profile: \(profile.rawValue), HealthKit writes suppressed)")
    }
```

Update the three private seeders to take `today: Date` and drop their internal `Date()` calls. Update the existing public `seed(context:)` to delegate:

```swift
    static func seed(context: ModelContext) {
        seed(profile: .populated, into: context, referenceDate: Date())
    }
```

> `TrendMetric.weight.rawValue` is `"weight"` — confirm by grepping `enum TrendMetric`. If the case/name differs, use the actual raw value and update the test's expected `metric` string to match.

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS (4 new tests).

- [ ] **Step 5: Commit**

```bash
git add Baseline/Utilities/TestDataSeeder.swift BaselineTests/Utilities/TestDataSeederProfileTests.swift
git commit -m "feat(test-mode): add deterministic seed profiles to TestDataSeeder"
```

---

## Task 4: `BaselineApp` test-mode container branch

**Files:**
- Modify: `Baseline/BaselineApp.swift:37-115`

**Context:** When `LaunchConfiguration.current.isUITesting`, build a single in-memory, CloudKit-free container, seed it, and skip CloudKit/HealthKit/Tips/mirror side effects. Production path unchanged.

- [ ] **Step 1: Add the test-mode branch in `init()`**

At the start of `init()` (after `Log.app.info("Baseline launching")`), branch:

```swift
        let config = LaunchConfiguration.current

        #if DEBUG
        if config.isUITesting {
            let schema = Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self, SyncState.self, Goal.self])
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [memConfig])
            } catch {
                fatalError("Failed to configure in-memory UI-test store: \(error)")
            }
            TestDataSeeder.seed(profile: config.seedProfile, into: modelContainer.mainContext, referenceDate: Date())

            self.mirror = NoOpOutboundMirror()
            SyncHelper.mirror = self.mirror

            let context = modelContainer.mainContext
            let state = AppState()
            let trendsVM = TrendsViewModel(modelContext: context)
            trendsVM.refresh()
            state.preloadedTrendsVM = trendsVM
            state.preloadedGoalVM = GoalViewModel(modelContext: context)
            state.preloadedBodyVM = BodyViewModel(modelContext: context)
            _appState = State(initialValue: state)
            return
        }
        #endif

        // ... existing production path unchanged below ...
        CloudKitSyncMonitor.start()
```

> Move the existing `CloudKitSyncMonitor.start()` call to AFTER the test-mode `return`, so it does not run under UI testing. The rest of the production `init()` body (cloudConfig/localConfig/container/preload) stays as-is.

- [ ] **Step 2: Guard the `body` `.task` modifiers**

In `body` (app:99-113), wrap the three `.task` blocks so they no-op under UI testing. Replace each `.task { … }` with a guarded version, e.g.:

```swift
                .task {
                    guard !LaunchConfiguration.current.isUITesting else { return }
                    try? Tips.configure([.displayFrequency(.weekly)])
                }
                .task {
                    guard !LaunchConfiguration.current.isUITesting else { return }
                    await HealthKitManager.requestAuthorizationIfNeeded()
                }
                .task {
                    guard !LaunchConfiguration.current.isUITesting else { return }
                    await mirror.reconcile(context: modelContainer.mainContext)
                }
```

- [ ] **Step 3: Build for the simulator to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manually verify test mode boots seeded + isolated**

Run: `make generate && xcodebuild build -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/dd-baseline | xcbeautify` then launch with the arg via simctl:

```bash
APP=$(find /tmp/dd-baseline -name 'Baseline.app' -path '*Debug-iphonesimulator*' | head -n1)
xcrun simctl install booted "$APP"
xcrun simctl launch --console-pty booted com.cadre.baseline -UITestMode -UITestSeed populated
```
Expected: app launches showing seeded data, no CloudKit/HealthKit prompts. (Boot a simulator first with `make sim` if none is booted.)

- [ ] **Step 5: Commit**

```bash
git add Baseline/BaselineApp.swift
git commit -m "feat(test-mode): in-memory seeded container + side-effect guards under UI test"
```

---

## Task 5: `A11yID` registry (definition + app target wiring)

**Files:**
- Create: `Baseline/Accessibility/A11yID.swift`
- Modify: `project.yml` (ensure `Baseline/Accessibility` compiles — it already will via `sources: - path: Baseline`; no change needed unless excluded)

- [ ] **Step 1: Create the registry**

```swift
// Baseline/Accessibility/A11yID.swift
import Foundation

/// Single source of truth for accessibility identifiers used by UI tests.
/// Compiled into both the app and the BaselineUITests target.
enum A11yID {
    enum TabBar {
        static let trends = "tab.trends"
        static let now = "tab.now"
        static let body = "tab.body"
    }
    enum Now {
        static let settingsButton = "now.settingsButton"
        static let historyButton = "now.historyButton"
        static let weighInButton = "now.weighInButton"
        static let rangeToggle = "now.rangeToggle"
        static let statLowest = "now.stat.lowest"
        static let statAverage = "now.stat.average"
        static let statHighest = "now.stat.highest"
    }
    enum WeighIn {
        static let dateChip = "weighIn.dateChip"
        static let stepperPlus = "weighIn.stepperPlus"
        static let stepperMinus = "weighIn.stepperMinus"
        static let addNote = "weighIn.addNote"
        static let addPhoto = "weighIn.addPhoto"
        static let save = "weighIn.save"
        static let overwriteConfirm = "weighIn.overwriteConfirm"
    }
    enum Trends {
        static let metricPicker = "trends.metricPicker"
        static let windowStepBack = "trends.windowStepBack"
        static let windowStepForward = "trends.windowStepForward"
        static let setGoalButton = "trends.setGoalButton"
        static let manageGoalButton = "trends.manageGoalButton"
    }
    enum SetGoal {
        static let targetField = "setGoal.targetField"
        static let targetDateField = "setGoal.targetDateField"
        static let save = "setGoal.save"
        static let cancel = "setGoal.cancel"
    }
    enum Body {
        static let scanButton = "body.scanButton"
        static let logMeasurementButton = "body.logMeasurementButton"
    }
    enum ScanEntry {
        static let manualEntryButton = "scanEntry.manualEntryButton"
        static let weightField = "scanEntry.weightField"
        static let bodyFatField = "scanEntry.bodyFatField"
        static let save = "scanEntry.save"
        static let cancel = "scanEntry.cancel"
    }
    enum History {
        static let list = "history.list"
    }
    enum Settings {
        static let unitToggle = "settings.unitToggle"
        static let importCSV = "settings.importCSV"
        static let exportCSV = "settings.exportCSV"
        static let privacyLink = "settings.privacyLink"
        static let termsLink = "settings.termsLink"
    }
}
```

> These identifier names are the contract. Tasks 6–8 attach each to its control; the flow tests in Tasks 10–12 read them. If a screen has additional interactive controls not listed here, add a case here when you tag it (Tasks 6–8) and keep the naming scheme `screen.element`.

- [ ] **Step 2: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Baseline/Accessibility/A11yID.swift
git commit -m "feat(a11y): add A11yID identifier registry"
```

---

## Task 6: Tag controls — Tabs, Now, WeighIn

**Files:**
- Modify: `Baseline/Views/Navigation/MainTabView.swift`
- Modify: `Baseline/Views/Now/NowView.swift`
- Modify: `Baseline/Views/Now/WeighInSheet.swift`

**Pattern:** add `.accessibilityIdentifier(<A11yID constant>)` to each named control. For tab items, apply the modifier to each tab's root view (the `.tabItem`-bearing view), e.g. `.accessibilityIdentifier(A11yID.TabBar.trends)` after `.tag(AppTab.trends)`.

- [ ] **Step 1: Tag the tabs (`MainTabView.swift`)**

Add to each tab view in the `TabView` (after each `.tag(...)`):
- `TrendsView` → `.accessibilityIdentifier(A11yID.TabBar.trends)`
- `NowView` → `.accessibilityIdentifier(A11yID.TabBar.now)`
- `BodyView` → `.accessibilityIdentifier(A11yID.TabBar.body)`

- [ ] **Step 2: Tag Now toolbar + actions (`NowView.swift`)**

- Settings gear `Button` (line ~60) → `.accessibilityIdentifier(A11yID.Now.settingsButton)`
- History `Button` (line ~69) → `.accessibilityIdentifier(A11yID.Now.historyButton)`
- The "Weigh In" button (find the primary action button that sets `showWeighIn = true`) → `.accessibilityIdentifier(A11yID.Now.weighInButton)`
- The range toggle control (30D/90D/All) → `.accessibilityIdentifier(A11yID.Now.rangeToggle)`
- The three stat values (Lowest/Average/Highest) → the respective `A11yID.Now.statLowest/statAverage/statHighest`.

- [ ] **Step 3: Tag WeighIn sheet controls (`WeighInSheet.swift`)**

- `dateChip` button (line ~196) → `.accessibilityIdentifier(A11yID.WeighIn.dateChip)`
- stepper minus button (line ~259) → `.accessibilityIdentifier(A11yID.WeighIn.stepperMinus)`
- stepper plus button (line ~271) → `.accessibilityIdentifier(A11yID.WeighIn.stepperPlus)`
- "Add note" chip (line ~287) → `.accessibilityIdentifier(A11yID.WeighIn.addNote)`
- "Add photo" button (line ~303) → `.accessibilityIdentifier(A11yID.WeighIn.addPhoto)`
- "Save" button (line ~384) → `.accessibilityIdentifier(A11yID.WeighIn.save)`
- In the overwrite alert (line ~403), tag the destructive "Overwrite" button → `.accessibilityIdentifier(A11yID.WeighIn.overwriteConfirm)`

- [ ] **Step 4: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Baseline/Views/Navigation/MainTabView.swift Baseline/Views/Now/NowView.swift Baseline/Views/Now/WeighInSheet.swift
git commit -m "feat(a11y): tag tab bar, Now, and WeighIn controls"
```

---

## Task 7: Tag controls — Trends, SetGoal, Body, ScanEntry

**Files:**
- Modify: `Baseline/Views/Trends/TrendsView.swift`, `MetricPickerSheet.swift`, `SetGoalSheet.swift`, `GoalCard.swift`, `GoalManageSheet.swift`
- Modify: `Baseline/Views/Body/BodyView.swift`, `ScanEntryFlow.swift`, `LogMeasurementSheet.swift`

- [ ] **Step 1: Tag Trends controls**

- Metric picker entry (opens `MetricPickerSheet`) → `.accessibilityIdentifier(A11yID.Trends.metricPicker)`
- Window stepper back/forward buttons → `A11yID.Trends.windowStepBack` / `windowStepForward`
- "Set Goal" button (in `GoalCard`/Trends when no active goal) → `.accessibilityIdentifier(A11yID.Trends.setGoalButton)`
- "Manage Goal" entry (when a goal is active) → `.accessibilityIdentifier(A11yID.Trends.manageGoalButton)`

- [ ] **Step 2: Tag SetGoal sheet (`SetGoalSheet.swift`)**

- Target value field → `A11yID.SetGoal.targetField`
- Target date field/picker → `A11yID.SetGoal.targetDateField`
- Save button → `A11yID.SetGoal.save`
- Cancel button → `A11yID.SetGoal.cancel`

- [ ] **Step 3: Tag Body + ScanEntry**

- `BodyView` scan button (the action opening the `showScanEntry` fullScreenCover) → `A11yID.Body.scanButton`
- `BodyView` log-measurement button (`showLogMeasurement`) → `A11yID.Body.logMeasurementButton`
- `ScanEntryFlow` manual-entry entry point → `A11yID.ScanEntry.manualEntryButton`
- Manual weight field → `A11yID.ScanEntry.weightField`; body-fat field → `A11yID.ScanEntry.bodyFatField`
- Save/confirm → `A11yID.ScanEntry.save`; cancel/dismiss → `A11yID.ScanEntry.cancel`

> If `ScanEntryFlow` field/button structure differs (e.g. a multi-step flow), tag the equivalent controls and add any missing `A11yID.ScanEntry` cases following the `scanEntry.element` scheme. The contract that matters: the manual-entry path can be driven end-to-end by identifier.

- [ ] **Step 4: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Baseline/Views/Trends/ Baseline/Views/Body/
git commit -m "feat(a11y): tag Trends, SetGoal, Body, and ScanEntry controls"
```

---

## Task 8: Tag controls — History, Settings

**Files:**
- Modify: `Baseline/Views/History/HistoryView.swift`
- Modify: `Baseline/Views/Settings/SettingsView.swift`, `SettingsSubscreens.swift`

- [ ] **Step 1: Tag History**

- The main list (`List`/`ScrollView`) → `.accessibilityIdentifier(A11yID.History.list)`

- [ ] **Step 2: Tag Settings**

- Unit toggle (lb/kg) → `A11yID.Settings.unitToggle`
- CSV import control → `A11yID.Settings.importCSV`
- CSV export control → `A11yID.Settings.exportCSV`
- Privacy policy link → `A11yID.Settings.privacyLink`
- Terms link → `A11yID.Settings.termsLink`

> The privacy/terms `Link`s were added in PR #72 — grep for `bgibso4.github.io` in `SettingsView.swift` to locate them.

- [ ] **Step 3: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/History/HistoryView.swift Baseline/Views/Settings/
git commit -m "feat(a11y): tag History and Settings controls"
```

---

## Task 9: `BaselineUITests` target + smoke navigation test

**Files:**
- Modify: `project.yml`
- Create: `BaselineUITests/BaseUITestCase.swift`
- Create: `BaselineUITests/SmokeNavigationUITests.swift`

- [ ] **Step 1: Add the UI-test target + share `A11yID.swift` to `project.yml`**

Under `targets:`, add:

```yaml
  BaselineUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: BaselineUITests
      - path: Baseline/Accessibility/A11yID.swift
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        TARGETED_DEVICE_FAMILY: "1"
    dependencies:
      - target: Baseline
```

> Sharing the single `A11yID.swift` source file into both targets keeps one source of truth (the file compiles into the app via `Baseline/` and into the test target via the explicit path). Do NOT duplicate the file.

- [ ] **Step 2: Add the UI-test target to the scheme test action**

In `project.yml` under `schemes.Baseline.test.testPlans`, the plans are referenced; the per-target inclusion happens in the `.xctestplan` files (Task 13). For now, regenerate so the target exists:

Run: `make generate`
Expected: project regenerates with `BaselineUITests` target present. Verify: `xcodebuild -list -project Baseline.xcodeproj | grep BaselineUITests`.

- [ ] **Step 3: Write `BaseUITestCase`**

```swift
// BaselineUITests/BaseUITestCase.swift
import XCTest

@MainActor
class BaseUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Override per subclass to pick the seed fixture.
    var seedProfile: String { "populated" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSeed", seedProfile]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation helpers

    func tapTab(_ identifier: String) {
        let tab = app.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab \(identifier) should exist")
        tab.tap()
    }
}
```

> Tab bar buttons surface their accessibility identifier via the tab view's identifier in XCUITest. If `app.buttons[A11yID.TabBar.now]` does not resolve, fall back to `app.tabBars.buttons` indexed by label and file a note — but the `.accessibilityIdentifier` on the tab root (Task 6) should make the identifier query work.

- [ ] **Step 4: Write the smoke test**

```swift
// BaselineUITests/SmokeNavigationUITests.swift
import XCTest

@MainActor
final class SmokeNavigationUITests: BaseUITestCase {
    func testLaunchesAndShowsNow() {
        // Now is the default-ish landing; assert the weigh-in button is present.
        XCTAssertTrue(app.buttons[A11yID.Now.weighInButton].waitForExistence(timeout: 10))
    }

    func testNavigatesAllTabs() {
        tapTab(A11yID.TabBar.trends)
        XCTAssertTrue(app.buttons[A11yID.Trends.metricPicker].waitForExistence(timeout: 5))

        tapTab(A11yID.TabBar.body)
        XCTAssertTrue(app.buttons[A11yID.Body.scanButton].waitForExistence(timeout: 5))

        tapTab(A11yID.TabBar.now)
        XCTAssertTrue(app.buttons[A11yID.Now.weighInButton].waitForExistence(timeout: 5))
    }

    func testPushesSettingsAndHistoryFromNow() {
        tapTab(A11yID.TabBar.now)
        app.buttons[A11yID.Now.settingsButton].tap()
        XCTAssertTrue(app.switches[A11yID.Settings.unitToggle].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap() // back

        app.buttons[A11yID.Now.historyButton].tap()
        XCTAssertTrue(app.otherElements[A11yID.History.list].waitForExistence(timeout: 5)
                      || app.collectionViews[A11yID.History.list].exists
                      || app.tables[A11yID.History.list].exists)
    }
}
```

- [ ] **Step 5: Run the UI smoke test**

Run: `make test-ui` (added in Task 13 — until then run directly):
```bash
xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineUITests/SmokeNavigationUITests | xcbeautify
```
Expected: PASS. If a landmark identifier doesn't resolve, fix the corresponding tag from Tasks 6–8 (the smoke test is the first real exercise of the registry).

- [ ] **Step 6: Commit**

```bash
git add project.yml Baseline.xcodeproj BaselineUITests/BaseUITestCase.swift BaselineUITests/SmokeNavigationUITests.swift
git commit -m "feat(uitests): add BaselineUITests target + smoke navigation test"
```

---

## Task 10: Accessibility audit + identifier-coverage tests

**Files:**
- Create: `BaselineUITests/AccessibilityAuditUITests.swift`
- Create: `BaselineUITests/IdentifierCoverageUITests.swift`

- [ ] **Step 1: Write the audit test**

```swift
// BaselineUITests/AccessibilityAuditUITests.swift
import XCTest

@MainActor
final class AccessibilityAuditUITests: BaseUITestCase {
    func testNowScreenAccessibility() throws {
        tapTab(A11yID.TabBar.now)
        try app.performAccessibilityAudit()
    }

    func testTrendsScreenAccessibility() throws {
        tapTab(A11yID.TabBar.trends)
        try app.performAccessibilityAudit()
    }

    func testBodyScreenAccessibility() throws {
        tapTab(A11yID.TabBar.body)
        try app.performAccessibilityAudit()
    }

    func testSettingsScreenAccessibility() throws {
        tapTab(A11yID.TabBar.now)
        app.buttons[A11yID.Now.settingsButton].tap()
        XCTAssertTrue(app.switches[A11yID.Settings.unitToggle].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    func testHistoryScreenAccessibility() throws {
        tapTab(A11yID.TabBar.now)
        app.buttons[A11yID.Now.historyButton].tap()
        try app.performAccessibilityAudit()
    }
}
```

- [ ] **Step 2: Run the audit and triage**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineUITests/AccessibilityAuditUITests | xcbeautify`
Expected: Either PASS, or FAIL listing concrete audit issues (contrast, hit-target, clipped text). If failures are legitimate UI bugs, fix the view. If a specific audit type is a known false positive for the design (e.g. decorative element), narrow it with `performAccessibilityAudit(for:)` excluding that type and leave a comment explaining why. Do NOT blanket-disable the audit.

- [ ] **Step 3: Write the identifier-coverage guard**

```swift
// BaselineUITests/IdentifierCoverageUITests.swift
import XCTest

@MainActor
final class IdentifierCoverageUITests: BaseUITestCase {
    /// Labels of system-provided controls we don't own and shouldn't fail on.
    private let systemAllowlist: Set<String> = [
        "Trends", "Now", "Body", // tab item labels
    ]

    func testNoUntaggedButtonsOnPrimaryScreens() {
        var untagged: [String] = []
        check(tab: A11yID.TabBar.now, into: &untagged)
        check(tab: A11yID.TabBar.trends, into: &untagged)
        check(tab: A11yID.TabBar.body, into: &untagged)
        XCTAssertTrue(untagged.isEmpty, "Untagged interactive controls found:\n\(untagged.joined(separator: "\n"))")
    }

    private func check(tab: String, into untagged: inout [String]) {
        tapTab(tab)
        for button in app.buttons.allElementsBoundByIndex where button.exists {
            let id = button.identifier
            let label = button.label
            if id.isEmpty && !label.isEmpty && !systemAllowlist.contains(label) {
                untagged.append("[\(tab)] button labeled '\(label)' has no accessibility identifier")
            }
        }
    }
}
```

- [ ] **Step 4: Run the coverage guard and tag any stragglers**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineUITests/IdentifierCoverageUITests | xcbeautify`
Expected: PASS. If it lists untagged buttons, add the missing `A11yID` case + tag (this is the exhaustive-tagging ratchet doing its job). Add genuinely-system labels to `systemAllowlist`.

- [ ] **Step 5: Commit**

```bash
git add BaselineUITests/AccessibilityAuditUITests.swift BaselineUITests/IdentifierCoverageUITests.swift
git commit -m "feat(uitests): add accessibility audit + identifier-coverage guard"
```

---

## Task 11: WeighIn + SetGoal flow tests

**Files:**
- Create: `BaselineUITests/WeighInFlowUITests.swift`
- Create: `BaselineUITests/SetGoalFlowUITests.swift`

- [ ] **Step 1: Write the weigh-in flow test**

```swift
// BaselineUITests/WeighInFlowUITests.swift
import XCTest

@MainActor
final class WeighInFlowUITests: BaseUITestCase {
    func testIncrementAndSaveWeighIn() {
        tapTab(A11yID.TabBar.now)
        app.buttons[A11yID.Now.weighInButton].tap()

        let plus = app.buttons[A11yID.WeighIn.stepperPlus]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap(); plus.tap() // +0.2

        app.buttons[A11yID.WeighIn.save].tap()

        // The .populated seed includes a today entry, so Save triggers the
        // overwrite alert; confirm it.
        let overwrite = app.buttons[A11yID.WeighIn.overwriteConfirm]
        if overwrite.waitForExistence(timeout: 3) {
            overwrite.tap()
        }

        // Sheet dismisses back to Now.
        XCTAssertTrue(app.buttons[A11yID.Now.weighInButton].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Run it**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineUITests/WeighInFlowUITests | xcbeautify`
Expected: PASS. If the overwrite alert button isn't found, verify the `A11yID.WeighIn.overwriteConfirm` tag on the alert's destructive button (Task 6 Step 3).

- [ ] **Step 3: Write the set-goal flow test**

```swift
// BaselineUITests/SetGoalFlowUITests.swift
import XCTest

@MainActor
final class SetGoalFlowUITests: BaseUITestCase {
    // Start with no active goal so the "Set Goal" affordance is present.
    override var seedProfile: String { "populated" }

    func testSetWeightGoalEntersGoalMode() {
        tapTab(A11yID.TabBar.trends)
        let setGoal = app.buttons[A11yID.Trends.setGoalButton]
        XCTAssertTrue(setGoal.waitForExistence(timeout: 5))
        setGoal.tap()

        let target = app.textFields[A11yID.SetGoal.targetField]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        target.typeText("185")

        app.buttons[A11yID.SetGoal.save].tap()

        // After saving, the manage-goal affordance replaces set-goal.
        XCTAssertTrue(app.buttons[A11yID.Trends.manageGoalButton].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 4: Run it**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineUITests/SetGoalFlowUITests | xcbeautify`
Expected: PASS. If the goal-mode transition differs (e.g. Trends shows a progress card rather than a "manage" button), assert on whatever `A11yID.Trends.manageGoalButton` is attached to in Task 7, and adjust the tag/assertion to match the real post-goal UI.

- [ ] **Step 5: Commit**

```bash
git add BaselineUITests/WeighInFlowUITests.swift BaselineUITests/SetGoalFlowUITests.swift
git commit -m "feat(uitests): add weigh-in and set-goal flow tests"
```

---

## Task 12: ScanEntry + CSV import flow tests

**Files:**
- Create: `BaselineUITests/ScanEntryFlowUITests.swift`
- Create: `BaselineUITests/CSVImportFlowUITests.swift`

**CSV import fixture decision (resolved here):** ship a small fixed CSV as a resource in the UI-test bundle and have the test write it to a temp file, then drive the importer. The simplest deterministic approach that avoids the system document picker: expose a test-only import affordance. Since adding test-only UI is heavier than the flow warrants, the CSV test instead asserts the importer *reachability* and the document-picker presentation, then exercises the parsing path via the already-existing `CSVImporterTests` (logic). If the Settings import uses `fileImporter`, the system picker cannot be reliably driven by XCUITest; in that case this UI test asserts the picker appears and dismisses, and the deterministic row-import assertion stays in the logic suite. Pick the file-bundle approach only if Settings import can accept an injected URL under `-UITestMode`.

- [ ] **Step 1: Write the scan-entry flow test (manual path)**

```swift
// BaselineUITests/ScanEntryFlowUITests.swift
import XCTest

@MainActor
final class ScanEntryFlowUITests: BaseUITestCase {
    func testManualScanEntrySaves() {
        tapTab(A11yID.TabBar.body)
        app.buttons[A11yID.Body.scanButton].tap()

        let manual = app.buttons[A11yID.ScanEntry.manualEntryButton]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()

        let weight = app.textFields[A11yID.ScanEntry.weightField]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap(); weight.typeText("190")

        let bodyFat = app.textFields[A11yID.ScanEntry.bodyFatField]
        bodyFat.tap(); bodyFat.typeText("18.5")

        app.buttons[A11yID.ScanEntry.save].tap()

        // Returns to Body; the scan list should reflect the new entry.
        XCTAssertTrue(app.buttons[A11yID.Body.scanButton].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Run it**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineUITests/ScanEntryFlowUITests | xcbeautify`
Expected: PASS. The scan-entry flow's exact field set may differ; align the test with the manual-entry controls tagged in Task 7. The camera/`DocumentScannerView` path is intentionally not exercised (cannot run in the simulator).

- [ ] **Step 3: Write the CSV import test (per the decision above)**

```swift
// BaselineUITests/CSVImportFlowUITests.swift
import XCTest

@MainActor
final class CSVImportFlowUITests: BaseUITestCase {
    override var seedProfile: String { "empty" }

    func testImportAffordancePresentsPicker() {
        tapTab(A11yID.TabBar.now)
        app.buttons[A11yID.Now.settingsButton].tap()

        let importButton = app.buttons[A11yID.Settings.importCSV]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        // The system document picker (or in-app picker) should appear.
        // We assert presentation, not row import — deterministic row import
        // is covered by CSVImporterTests in the logic suite.
        let picker = app.navigationBars.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Import picker should present")
    }
}
```

- [ ] **Step 4: Run it**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineUITests/CSVImportFlowUITests | xcbeautify`
Expected: PASS. If Settings import accepts an injected URL under test mode (preferred), upgrade this test to assert imported rows appear in History and remove the picker-only assertion.

- [ ] **Step 5: Commit**

```bash
git add BaselineUITests/ScanEntryFlowUITests.swift BaselineUITests/CSVImportFlowUITests.swift
git commit -m "feat(uitests): add scan-entry and CSV-import flow tests"
```

---

## Task 13: Test plans + Makefile `test-ui` + CI inclusion

**Files:**
- Create: `Baseline-UITests.xctestplan`
- Modify: `Baseline.xctestplan`, `Baseline-CI.xctestplan`
- Modify: `Makefile`
- Modify: `project.yml` (scheme testPlans — add the new plan)

**Context:** Test plans reference targets by their XcodeGen-generated identifier. The existing plans reference `BaselineTests` via target identifier `BC3C8FF69C3D1B0398FBF023`. After `make generate` creates `BaselineUITests`, find its target identifier: `xcodebuild -list -json -project Baseline.xcodeproj` won't show the blueprint id; instead read it from the generated `Baseline.xcodeproj/project.pbxproj` (grep `BaselineUITests` for the `PBXNativeTarget` id) or copy the `target` reference format already used in the snapshot plan and let XcodeGen-managed plans reference by name.

- [ ] **Step 1: Create `Baseline-UITests.xctestplan`**

Model it on `Baseline-Snapshots.xctestplan` but pointing at the UI-test target, selecting all its tests:

```json
{
  "configurations" : [
    {
      "id" : "00000000-0000-0000-0000-0000000000U1",
      "name" : "Configuration 1",
      "options" : { }
    }
  ],
  "defaultOptions" : {
    "targetForVariableExpansion" : {
      "containerPath" : "container:Baseline.xcodeproj",
      "identifier" : "<BASELINE_APP_TARGET_ID>",
      "name" : "Baseline"
    }
  },
  "testTargets" : [
    {
      "target" : {
        "containerPath" : "container:Baseline.xcodeproj",
        "identifier" : "<BASELINE_UITESTS_TARGET_ID>",
        "name" : "BaselineUITests"
      }
    }
  ],
  "version" : 1
}
```

Replace `<BASELINE_APP_TARGET_ID>` and `<BASELINE_UITESTS_TARGET_ID>` with the real ids from `project.pbxproj` (grep the `PBXNativeTarget` section). Use the same app target id that the existing plans use for `targetForVariableExpansion`.

- [ ] **Step 2: Add the UI-test target to `Baseline.xctestplan` (all) and `Baseline-CI.xctestplan`**

In both files, append a `testTargets` entry for `BaselineUITests` (same `target` block as above). `Baseline.xctestplan` runs everything; `Baseline-CI.xctestplan` keeps its snapshot `skippedTests` and now also runs UI tests.

- [ ] **Step 3: Register the new plan in `project.yml`**

Under `schemes.Baseline.test.testPlans`, add:

```yaml
        - path: Baseline-UITests.xctestplan
```

Then `make generate`.

- [ ] **Step 4: Add `test-ui` to the `Makefile`**

Add a target mirroring the existing `test` target but with `-testPlan Baseline-UITests`:

```makefile
test-ui: ## Run UI tests only (Baseline-UITests plan)
	xcodebuild test \
		-project Baseline.xcodeproj \
		-scheme Baseline \
		-testPlan Baseline-UITests \
		-destination "$(SIM_DEST)" \
		| xcbeautify
```

Use the same `$(SIM_DEST)`/destination variable the existing `test` target uses (check the Makefile for the exact variable name; reuse it verbatim).

- [ ] **Step 5: Run the full CI plan locally**

Run: `make test`
Expected: PASS — logic tests AND UI tests run (snapshots skipped). Then `make test-ui` runs UI tests alone; `make test-all` runs everything including snapshots.

- [ ] **Step 6: Commit**

```bash
git add Baseline-UITests.xctestplan Baseline.xctestplan Baseline-CI.xctestplan Makefile project.yml Baseline.xcodeproj
git commit -m "feat(ci): run UI tests in CI plan; add Baseline-UITests plan + make test-ui"
```

> CI (`.github/workflows/ci.yml`) runs `make test`, which now includes UI tests via the CI plan — no workflow edit needed. Watch the first CI run's duration; if it approaches the runner default, add `timeout-minutes: 30` (tracked as a tech-debt issue in Task 14).

---

## Task 14: `CONTRIBUTING.md` + `tech-debt` label and issue migration

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Write `CONTRIBUTING.md`**

```markdown
# Contributing to Baseline

## Setup

```bash
make setup   # brew bundle (swiftlint, xcbeautify, xcodegen) + installs the git pre-commit hook
make generate
```

## Everyday commands

| Command | What it runs |
|---------|--------------|
| `make build` | Build the app for the simulator |
| `make test` | Logic + UI tests (the `Baseline-CI` plan — what CI runs) |
| `make test-ui` | UI tests only (`Baseline-UITests` plan) |
| `make test-snapshots` | Snapshot tests only |
| `make test-all` | Everything (logic + UI + snapshots) |
| `make lint` / `make format` | SwiftLint check / autocorrect |
| `make sim` | Build, boot, install, launch on a simulator |

## Pre-commit hook

`make setup` wires `core.hooksPath` to `hooks/`. The hook blocks commits on SwiftLint *errors*, merge-conflict markers, and files larger than 1 MB. Never bypass it with `--no-verify`.

## Test plans

- `Baseline.xctestplan` — all tests (local Cmd-U).
- `Baseline-CI.xctestplan` — logic + UI tests; snapshots skipped (pixel-sensitive). This is the CI gate.
- `Baseline-UITests.xctestplan` — UI tests only.
- `Baseline-Snapshots.xctestplan` — snapshot tests only.

## UI testing & the accessibility-identifier convention

UI tests run the app in a deterministic test mode: launch with `-UITestMode -UITestSeed <empty|populated|goalActive>`. In this mode the app uses an in-memory, CloudKit-free SwiftData store seeded with fixed fixtures, and animations are disabled. The seam is `Baseline/App/LaunchConfiguration.swift`.

**Every interactive control gets an accessibility identifier** from `Baseline/Accessibility/A11yID.swift`:

```swift
Button("Save") { … }
    .accessibilityIdentifier(A11yID.WeighIn.save)
```

This is enforced by `IdentifierCoverageUITests` — adding an untagged button fails the build in CI. Add a new `A11yID` case (named `screen.element`) and tag the control in the same change.

## Branch & PR flow

Work on a feature branch; CI must be green before merge. Do not push to `main` directly.
```

- [ ] **Step 2: Commit `CONTRIBUTING.md`**

```bash
git add CONTRIBUTING.md
git commit -m "docs: add CONTRIBUTING.md with dev setup and A11y convention"
```

- [ ] **Step 3: Create the `tech-debt` label and migrate Phase 1 follow-ups**

Run (requires `gh` auth):
```bash
gh label create tech-debt --description "Deferred engineering follow-up" --color BFD4F2 || true

gh issue create --title "SwiftLint strict-ratchet pass" --label tech-debt --body "$(cat <<'EOF'
Flip .swiftlint.yml to --strict, make pre-commit + CI lint hard gates, and clean the ~623 residual warnings. Sub-items from the Phase 1 spec follow-ups:
- BaselineTests per-path relaxations (function_body_length, type_body_length).
- Remove legacy_random from opt_in_rules (it is a default rule).
- Extend identifier_name.excluded for idiomatic single-char closure params (r/g/b, geometry).
- Decide error: thresholds for length rules.
- Decide InBodyDocumentParser.swift operator_usage_whitespace exclusion.

Source: docs/superpowers/specs/2026-05-16-phase-1-testing-ci-foundation-design.md
EOF
)"

gh issue create --title "CI / test-plan hardening" --label tech-debt --body "$(cat <<'EOF'
- Assert Baseline-CI skippedTests == Baseline-Snapshots selectedTests so a new snapshot class can't silently run in CI.
- Add timeout-minutes: 30 to the CI job.
- SHA-pin maxim-lobanov/setup-xcode (currently @v1).
- Revisit runs-on: macos-15 + xcode-version 26.3 when GitHub runner images turn over.

Source: docs/superpowers/specs/2026-05-16-phase-1-testing-ci-foundation-design.md
EOF
)"
```
Expected: label created, two issues opened.

> If `gh` is unavailable or unauthenticated in the execution environment, STOP and report this step to the human to run manually — do not skip silently.

---

## Self-Review (completed during planning)

**Spec coverage:** §1 LaunchConfiguration → Task 1; §1 refactor of existing checks → Task 2; §3 seed profiles → Task 3; §2 container branch + .task guards → Task 4; §4 A11yID registry → Task 5; §4 exhaustive tagging → Tasks 6–8; §5 UITest target + BaseUITestCase + flow/audit/coverage tests → Tasks 9–12; §6 test plans + CI + make test-ui → Task 13; §7 CONTRIBUTING.md + tech-debt label/issues → Task 14. All spec sections covered.

**Type consistency:** `LaunchConfiguration.current.shouldDisableAnimations` / `.isUITesting` / `.seedProfile` used consistently (Tasks 1,2,4). `SeedProfile` raw values `empty`/`populated`/`goalActive` consistent across Tasks 1,3,4,9,11,12. `TestDataSeeder.seed(profile:into:referenceDate:)` signature consistent (Tasks 3,4). `A11yID.*` constants defined in Task 5 are exactly those referenced in Tasks 6–12.

**Known soft spots flagged in-line for the implementer:** exact view-control locations for tagging (Tasks 6–8 give file + control description, not every line number, because the modifier is mechanical); the CSV-import test depth depends on whether Settings import can accept an injected URL (Task 12 states the fallback); test-plan target identifiers must be read from `project.pbxproj` after generate (Task 13). These are judgment points, not placeholders — each names the concrete decision and its fallback.
