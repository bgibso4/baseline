# Onboarding Flow (Issue #5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** First-launch onboarding (Welcome → Name), a personalized time-aware greeting on the Now screen, and removal of the vestigial Height/Age/Gender Settings fields.

**Architecture:** A two-page `OnboardingFlow` is presented by `BaselineApp` instead of `MainTabView` until a `hasCompletedOnboarding` UserDefaults flag is set (suppressed under UI testing). Greeting logic is a pure `Greeting` helper surfaced through `NowViewModel` with an injectable clock. Settings loses three orphaned editors and their ViewModel plumbing.

**Tech Stack:** SwiftUI + MVVM (`@Observable`), UserDefaults via `@AppStorage`/injected defaults, XCTest (logic plan, no simulator for unit tests), XCUITest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-06-09-onboarding-flow-design.md`
**Approved mocks:** `docs/mockups/onboarding-welcome-APPROVED-variant-c-2026-06-08.html`, `docs/mockups/now-greeting-APPROVED-variant-b-2026-06-09.html`

---

## Conventions for every task

- **Branch:** all work happens on `feat/onboarding-5-welcome-name` (already created).
- **After adding/deleting files:** run `make generate` (XcodeGen) BEFORE building or testing. Forgetting this is the #1 cause of "file not found" build failures here.
- **Fast unit-test loop** (replace the `-only-testing` value per task):

  ```bash
  set -o pipefail && xcodebuild test \
    -project Baseline.xcodeproj -scheme Baseline -testPlan Baseline-CI \
    -destination "platform=iOS Simulator,name=$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+ Pro' | grep -v Max | grep -oE 'iPhone [0-9]+ Pro' | head -n1)" \
    -derivedDataPath .build/DerivedData \
    -only-testing:BaselineTests/GreetingTests | xcbeautify
  ```

- **Full gate** (run at the end, not per task — it includes UI tests and is slow): `make test` and `make lint`.
- **Snapshot suites are NOT in the CI gate** (`Baseline-CI.xctestplan` skips all `*SnapshotTests`). Local snapshot runs currently fail on clean main due to a simulator/Xcode environment mismatch (issue #79) — **do not** treat snapshot failures as regressions and do not try to re-record references in this work. We still update snapshot *test code* so it stays correct for the eventual #79 re-record.
- **UserDefaults keys are raw string literals** in this codebase (`"userName"`, `"weightUnit"`, …). Follow that convention; do not invent a key-constants type. The two keys this plan touches: `"userName"` (existing) and `"hasCompletedOnboarding"` (new). Spell them exactly.
- **No `print()`** — use `Log.<category>` if logging is ever needed (it isn't, in this plan).
- **Commit after every task.** Before each commit, run `git status --short` and confirm nothing unexpected is modified/untracked (a dirty tree with orphaned files still builds green — check explicitly).

## File map

**Create:**

| File | Responsibility |
|------|----------------|
| `Baseline/Utilities/Greeting.swift` | Pure time-of-day salutation logic (no UI imports) |
| `Baseline/Views/Onboarding/OnboardingFlow.swift` | Root container: page state, transitions |
| `Baseline/Views/Onboarding/OnboardingWelcomeView.swift` | Page 1 — warm welcome (approved mock variant C) |
| `Baseline/Views/Onboarding/OnboardingNameView.swift` | Page 2 — optional name entry |
| `Baseline/Views/Onboarding/OnboardingButtons.swift` | Shared primary/ghost CTA buttons for onboarding pages |
| `Baseline/ViewModels/OnboardingViewModel.swift` | Name draft + completion writes (injectable defaults) |
| `Baseline/Design/Components/EKGMark.swift` | The EKG mark as a strokable `Shape` |
| `BaselineTests/Utilities/GreetingTests.swift` | Salutation boundary tests |
| `BaselineTests/ViewModels/OnboardingViewModelTests.swift` | Completion-write tests |
| `BaselineUITests/OnboardingFlowUITests.swift` | End-to-end onboarding walk |

**Modify:**

| File | Change |
|------|--------|
| `Baseline/ViewModels/NowViewModel.swift` | Add injectable clock + `greetingSalutation` |
| `Baseline/Views/Now/NowView.swift` | Top-centered greeting header |
| `Baseline/App/LaunchConfiguration.swift` | Parse `-UITestShowOnboarding` → `forceOnboarding` |
| `Baseline/BaselineApp.swift` | Root branch onboarding vs MainTabView; UI-test flag reset |
| `Baseline/Accessibility/A11yID.swift` | `Onboarding` enum + `Settings.showOnboardingAgain` |
| `Baseline/Views/Settings/SettingsView.swift` | Profile section → Name row only |
| `Baseline/ViewModels/SettingsViewModel.swift` | Remove `Gender`, height/birthday/gender plumbing |
| `Baseline/Views/Settings/NameEditView.swift` | Honest help text |
| `Baseline/Views/Settings/SettingsDeveloperSection.swift` | "Show Onboarding Again" row |
| `BaselineUITests/BaseUITestCase.swift` | `extraLaunchArguments` hook |
| `BaselineTests/App/LaunchConfigurationTests.swift` | Cover `forceOnboarding` |
| `BaselineTests/Snapshots/NowViewSnapshotTests.swift` | Inject fixed clock for greeting determinism |
| `BaselineTests/Snapshots/SettingsViewSnapshotTests.swift` | Drop height/gender/birthday seeding |

**Delete:**

- `Baseline/Views/Settings/HeightPickerView.swift`
- `Baseline/Views/Settings/BirthdayPickerView.swift`
- `Baseline/Views/Settings/GenderPickerView.swift`

---

### Task 1: `Greeting` helper (pure logic, TDD)

**Files:**
- Create: `Baseline/Utilities/Greeting.swift`
- Create: `BaselineTests/Utilities/GreetingTests.swift`

- [ ] **Step 1: Write the failing test**

Create `BaselineTests/Utilities/GreetingTests.swift`:

```swift
import XCTest
@testable import Baseline

final class GreetingTests: XCTestCase {
    /// Fixed date at the given hour — keeps assertions independent of run time.
    private func date(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: hour))!
    }

    func testMorningSpansFiveToElevenInclusive() {
        XCTAssertEqual(Greeting.salutation(at: date(hour: 5)), "Good morning")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 11)), "Good morning")
    }

    func testAfternoonSpansNoonToFourInclusive() {
        XCTAssertEqual(Greeting.salutation(at: date(hour: 12)), "Good afternoon")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 16)), "Good afternoon")
    }

    func testEveningSpansSeventeenThroughFourWrappingMidnight() {
        XCTAssertEqual(Greeting.salutation(at: date(hour: 17)), "Good evening")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 23)), "Good evening")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 0)), "Good evening")
        XCTAssertEqual(Greeting.salutation(at: date(hour: 4)), "Good evening")
    }
}
```

- [ ] **Step 2: Regenerate project and run the test to verify it fails**

```bash
make generate
```

Then run the fast unit-test loop with `-only-testing:BaselineTests/GreetingTests`.
Expected: **build failure** — `cannot find 'Greeting' in scope`. (A compile error in the test target is this codebase's equivalent of a red test for a brand-new type.)

- [ ] **Step 3: Write the implementation**

Create `Baseline/Utilities/Greeting.swift`:

```swift
import Foundation

/// Pure time-of-day greeting logic for the Now screen header.
/// No SwiftUI/UIKit imports — unit-testable without a simulator.
enum Greeting {
    /// "Good morning" 05:00–11:59, "Good afternoon" 12:00–16:59,
    /// "Good evening" otherwise (17:00 through 04:59, wrapping midnight).
    static func salutation(at date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Same command. Expected: `GreetingTests` — 3 tests, all PASS.

- [ ] **Step 5: Commit**

```bash
git status --short   # expect exactly the two new files
git add Baseline/Utilities/Greeting.swift BaselineTests/Utilities/GreetingTests.swift Baseline.xcodeproj
git commit -m "feat: pure Greeting salutation helper with injectable clock"
```

---

### Task 2: `NowViewModel` exposes the salutation (injectable clock)

**Files:**
- Modify: `Baseline/ViewModels/NowViewModel.swift`
- Modify: `BaselineTests/ViewModels/NowViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `BaselineTests/ViewModels/NowViewModelTests.swift` (inside the class):

```swift
    func testGreetingSalutationUsesInjectedClock() {
        let nineAM = Calendar.current.date(
            from: DateComponents(year: 2026, month: 6, day: 9, hour: 9))!
        let vm = NowViewModel(modelContext: context, now: { nineAM })
        XCTAssertEqual(vm.greetingSalutation, "Good morning")

        let ninePM = Calendar.current.date(
            from: DateComponents(year: 2026, month: 6, day: 9, hour: 21))!
        let eveningVM = NowViewModel(modelContext: context, now: { ninePM })
        XCTAssertEqual(eveningVM.greetingSalutation, "Good evening")
    }
```

- [ ] **Step 2: Run to verify it fails**

Fast loop with `-only-testing:BaselineTests/NowViewModelTests`.
Expected: build failure — `extra argument 'now' in call` / `no member 'greetingSalutation'`.

- [ ] **Step 3: Implement**

In `Baseline/ViewModels/NowViewModel.swift`:

Replace the stored properties + init:

```swift
    private let modelContext: ModelContext
    /// Injectable clock so greeting output is deterministic in tests/snapshots.
    private let now: () -> Date
```

```swift
    init(modelContext: ModelContext, now: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.now = now
    }
```

Add below the `unit` property:

```swift
    /// Time-aware salutation for the Now header ("Good morning" / …).
    var greetingSalutation: String {
        Greeting.salutation(at: now())
    }
```

- [ ] **Step 4: Run to verify it passes**

Same command. Expected: all `NowViewModelTests` PASS (existing + new).

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/NowViewModel.swift BaselineTests/ViewModels/NowViewModelTests.swift
git commit -m "feat: NowViewModel greetingSalutation with injectable clock"
```

---

### Task 3: Now-screen greeting header (top-centered, approved variant B)

**Files:**
- Modify: `Baseline/Views/Now/NowView.swift`
- Modify: `BaselineTests/Snapshots/NowViewSnapshotTests.swift`

Visual target: `docs/mockups/now-greeting-APPROVED-variant-b-2026-06-09.html` — small secondary salutation line, Exo 2 bold name beneath, centered; hero/stats/button untouched.

- [ ] **Step 1: Add the `@AppStorage` name and greeting header to `NowView`**

In `Baseline/Views/Now/NowView.swift`, below the existing `@AppStorage("weightUnit")` line, add:

```swift
    // Greeting name — @AppStorage so the header updates live when the user
    // edits their name in Settings (plain defaults reads would go stale).
    @AppStorage("userName") private var userName = ""
```

In `body`, change the main `VStack` so the greeting leads it:

```swift
                VStack(spacing: 0) {
                    greetingHeader
                        .padding(.top, 8)
                        .padding(.horizontal, CadreSpacing.md)

                    // Hero: arc + number + range toggle, centered in open area
                    Spacer(minLength: 0)
```

(The rest of the VStack — `heroGroup`, `Spacer`, `bottomBlock` — is unchanged.)

Add a new section after the `// MARK: - Hero group` block:

```swift
    // MARK: - Greeting header (top-centered, mock variant B)

    /// Trimmed display name, or nil when unset — never render an empty name line.
    private var greetingName: String? {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var greetingHeader: some View {
        let salutation = vm?.greetingSalutation ?? Greeting.salutation()
        // Trailing comma only when a name line follows — no dangling "Good morning,".
        return VStack(spacing: 3) {
            Text(greetingName != nil ? "\(salutation)," : salutation)
                .font(.footnote.weight(.medium))
                .tracking(0.2)
                .foregroundStyle(CadreColors.textSecondary)
            if let name = greetingName {
                Text(name)
                    .font(.custom("Exo 2", size: 20, relativeTo: .title3).weight(.bold))
                    .tracking(-0.3)
                    .foregroundStyle(CadreColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        // Single VoiceOver element: "Good morning, Ben" — avoids the comma-only
        // first line reading awkwardly on its own.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(greetingName.map { "\(salutation), \($0)" } ?? salutation)
    }
```

- [ ] **Step 2: Make the NowView snapshot deterministic for the greeting**

In `BaselineTests/Snapshots/NowViewSnapshotTests.swift`, the test builds `NowViewModel(modelContext: container.mainContext)`. Change that line to inject a fixed mid-morning clock:

```swift
        // Fixed 9 AM clock — greeting salutation must not depend on when the
        // suite runs (the seeded fixture dates are already deterministic).
        let snapshotNow = Calendar.current.date(
            from: DateComponents(year: 2026, month: 6, day: 9, hour: 9))!
        let vm = NowViewModel(modelContext: container.mainContext, now: { snapshotNow })
```

Do NOT re-record the reference PNG — that happens under issue #79. The reference is now stale; that's expected and the suite is excluded from `Baseline-CI`.

- [ ] **Step 3: Build and eyeball**

```bash
make build
```

Expected: BUILD SUCCEEDED. Optionally run the app in the simulator and confirm: with no name set, a single centered "Good morning/afternoon/evening" under the nav bar; the hero arc keeps its centered position.

- [ ] **Step 4: Run the logic tests to confirm nothing regressed**

Fast loop with `-only-testing:BaselineTests/NowViewModelTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Baseline/Views/Now/NowView.swift BaselineTests/Snapshots/NowViewSnapshotTests.swift
git commit -m "feat: time-aware top-centered greeting on Now screen (mock variant B)"
```

---

### Task 4: `OnboardingViewModel` (completion writes, TDD)

**Files:**
- Create: `Baseline/ViewModels/OnboardingViewModel.swift`
- Create: `BaselineTests/ViewModels/OnboardingViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `BaselineTests/ViewModels/OnboardingViewModelTests.swift`:

```swift
import XCTest
@testable import Baseline

final class OnboardingViewModelTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "OnboardingVMTests")!
        defaults.removePersistentDomain(forName: "OnboardingVMTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "OnboardingVMTests")
        defaults = nil
        super.tearDown()
    }

    func testCompleteSetsFlagWithoutWritingName() {
        let vm = OnboardingViewModel(defaults: defaults)
        vm.complete()
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertNil(defaults.string(forKey: "userName"))
    }

    func testCompleteSavingNameTrimsPersistsAndSetsFlag() {
        let vm = OnboardingViewModel(defaults: defaults)
        vm.draftName = "  Ben "
        vm.completeSavingName()
        XCTAssertEqual(defaults.string(forKey: "userName"), "Ben")
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    func testCompleteSavingNameWithBlankDraftBehavesLikeSkip() {
        let vm = OnboardingViewModel(defaults: defaults)
        vm.draftName = "   "
        vm.completeSavingName()
        XCTAssertNil(defaults.string(forKey: "userName"))
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }
}
```

- [ ] **Step 2: `make generate`, run to verify failure**

```bash
make generate
```

Fast loop with `-only-testing:BaselineTests/OnboardingViewModelTests`.
Expected: build failure — `cannot find 'OnboardingViewModel' in scope`.

- [ ] **Step 3: Implement**

Create `Baseline/ViewModels/OnboardingViewModel.swift`:

```swift
import Foundation
import Observation

/// Drives the first-launch onboarding flow: holds the name draft and performs
/// the completion writes. Views stay logic-free; tests inject a scratch
/// UserDefaults suite. `BaselineApp` observes "hasCompletedOnboarding" via
/// @AppStorage, so writing the flag here is what dismisses the flow.
@Observable
final class OnboardingViewModel {
    private let defaults: UserDefaults

    var draftName: String = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// "Continue" on the name page: persist a non-empty trimmed name, then finish.
    /// A blank draft behaves exactly like Skip — no empty-string name is stored.
    func completeSavingName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            defaults.set(trimmed, forKey: "userName")
        }
        complete()
    }

    /// Any skip path: finish without writing a name.
    func complete() {
        defaults.set(true, forKey: "hasCompletedOnboarding")
    }
}
```

- [ ] **Step 4: Run to verify pass**

Same command. Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/OnboardingViewModel.swift BaselineTests/ViewModels/OnboardingViewModelTests.swift Baseline.xcodeproj
git commit -m "feat: OnboardingViewModel — name draft + completion writes"
```

---

### Task 5: A11y identifiers, EKG mark shape, shared onboarding buttons

**Files:**
- Modify: `Baseline/Accessibility/A11yID.swift`
- Create: `Baseline/Design/Components/EKGMark.swift`
- Create: `Baseline/Views/Onboarding/OnboardingButtons.swift`

No logic — scaffolding the views need. (CLAUDE.md hard rule: every interactive control gets an A11yID in the same change; we add them here so Tasks 6–8 can reference them.)

- [ ] **Step 1: Add A11yID cases**

In `Baseline/Accessibility/A11yID.swift`:

Inside `enum Settings { … }`, after `importChooseFile`, add:

```swift
        /// DEBUG developer row that clears the onboarding-completed flag.
        static let showOnboardingAgain = "settings.showOnboardingAgain"
```

After the closing brace of `enum Settings`, before the closing brace of `A11yID`, add:

```swift
    enum Onboarding {
        static let getStarted = "onboarding.getStarted"
        static let skipForNow = "onboarding.skipForNow"
        static let nameField = "onboarding.nameField"
        static let continueButton = "onboarding.continue"
        static let skipName = "onboarding.skipName"
    }
```

- [ ] **Step 2: Create the EKG mark shape**

Create `Baseline/Design/Components/EKGMark.swift`:

```swift
import SwiftUI

/// The Baseline EKG mark as a strokable shape. Geometry matches the approved
/// onboarding mock's 100×56 viewBox (flat baseline → spike → dip → recovery):
/// `docs/mockups/onboarding-welcome-APPROVED-variant-c-2026-06-08.html`.
struct EKGMark: Shape {
    /// Polyline control points in the mock's 100×56 coordinate space.
    private static let points: [CGPoint] = [
        CGPoint(x: 2, y: 34), CGPoint(x: 30, y: 34), CGPoint(x: 38, y: 34),
        CGPoint(x: 44, y: 14), CGPoint(x: 52, y: 46), CGPoint(x: 60, y: 26),
        CGPoint(x: 66, y: 34), CGPoint(x: 98, y: 34)
    ]

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 100
        let scaleY = rect.height / 56
        let scaled = Self.points.map {
            CGPoint(x: rect.minX + $0.x * scaleX, y: rect.minY + $0.y * scaleY)
        }
        var path = Path()
        path.move(to: scaled[0])
        for point in scaled.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

#Preview {
    EKGMark()
        .stroke(CadreColors.accentLight,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .frame(width: 108, height: 60)
        .padding()
        .background(CadreColors.bg)
}
```

- [ ] **Step 3: Create the shared onboarding buttons**

Create `Baseline/Views/Onboarding/OnboardingButtons.swift`:

```swift
import SwiftUI

/// Primary CTA used across onboarding pages — mirrors the Weigh In button
/// treatment. accentButton (#606E85) rather than accent (#6B7B94) because
/// white-on-accent is only 4.3:1, below WCAG AA for normal text.
struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CadreTypography.buttonLabel)
                .tracking(0.3)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(CadreColors.accentButton)
                )
        }
    }
}

/// Quiet secondary action ("Skip") — no fill, secondary text, full-width
/// tap target.
struct OnboardingGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CadreTypography.buttonLabel)
                .foregroundStyle(CadreColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
    }
}
```

- [ ] **Step 4: Regenerate, build**

```bash
make generate && make build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Baseline/Accessibility/A11yID.swift Baseline/Design/Components/EKGMark.swift Baseline/Views/Onboarding/OnboardingButtons.swift Baseline.xcodeproj
git commit -m "feat: onboarding A11y IDs, EKG mark shape, shared CTA buttons"
```

---

### Task 6: Welcome page (approved mock variant C)

**Files:**
- Create: `Baseline/Views/Onboarding/OnboardingWelcomeView.swift`

Visual target: `docs/mockups/onboarding-welcome-APPROVED-variant-c-2026-06-08.html` — left-aligned, conversational, expectation-setting. **Copy note:** the mock's subline ("make your scans and trends more accurate") predates the scope cut and is factually wrong — the copy below reflects the real payoff (the greeting). The mock's "Let's go" CTA was superseded by "Get started" in the approved spec.

- [ ] **Step 1: Create the view**

Create `Baseline/Views/Onboarding/OnboardingWelcomeView.swift`:

```swift
import SwiftUI

/// Page 1 of onboarding — warm, conversational welcome. Left-aligned per the
/// approved mock (variant C); sets expectations up front: short, optional,
/// skippable. Copy reflects the post-audit scope (name → greeting), not the
/// mock's original "scan accuracy" subline.
struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            EKGMark()
                .stroke(CadreColors.accentLight,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 54, height: 30)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            Text("Let's set\nyou up.")
                .font(.custom("Exo 2", size: 34, relativeTo: .largeTitle).weight(.bold))
                .tracking(-0.6)
                .lineSpacing(2)
                .foregroundStyle(CadreColors.textPrimary)

            Text("Baseline can greet you by name. It takes a few seconds — and you can skip it.")
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(CadreColors.textSecondary)
                .padding(.top, 16)

            Spacer()

            OnboardingPrimaryButton(title: "Get started", action: onGetStarted)
                .accessibilityIdentifier(A11yID.Onboarding.getStarted)
            OnboardingGhostButton(title: "Skip for now", action: onSkip)
                .accessibilityIdentifier(A11yID.Onboarding.skipForNow)
                .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }
}

#Preview {
    ZStack {
        GradientBackground(center: .top)
        OnboardingWelcomeView(onGetStarted: {}, onSkip: {})
    }
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build**

```bash
make build
```

Expected: BUILD SUCCEEDED. (New file in an existing-glob directory created in Task 5 — XcodeGen picked up `Views/Onboarding/` already, but if the build can't find the file, run `make generate` first.)

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Onboarding/OnboardingWelcomeView.swift Baseline.xcodeproj
git commit -m "feat: onboarding welcome page (approved mock variant C)"
```

---

### Task 7: Name page

**Files:**
- Create: `Baseline/Views/Onboarding/OnboardingNameView.swift`

- [ ] **Step 1: Create the view**

Create `Baseline/Views/Onboarding/OnboardingNameView.swift`:

```swift
import SwiftUI

/// Page 2 of onboarding — optional name entry. Input card mirrors
/// `NameEditView`'s treatment. All exits (Continue, Skip, keyboard Done)
/// complete onboarding via the view model; a blank Continue behaves like Skip.
struct OnboardingNameView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What should we call you?")
                .font(.custom("Exo 2", size: 28, relativeTo: .title).weight(.bold))
                .tracking(-0.5)
                .foregroundStyle(CadreColors.textPrimary)
                .padding(.top, 32)

            Text("Shown in your greeting on the Now screen.")
                .font(.subheadline)
                .foregroundStyle(CadreColors.textSecondary)
                .padding(.top, 10)

            TextField("Your name", text: $viewModel.draftName)
                .font(.custom("Exo 2", size: 18, relativeTo: .headline).weight(.semibold))
                .foregroundStyle(CadreColors.textPrimary)
                .tint(CadreColors.accent)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { viewModel.completeSavingName() }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CadreColors.accent, lineWidth: 1)
                )
                .padding(.top, 28)
                .accessibilityIdentifier(A11yID.Onboarding.nameField)

            Spacer()

            OnboardingPrimaryButton(title: "Continue") {
                viewModel.completeSavingName()
            }
            .accessibilityIdentifier(A11yID.Onboarding.continueButton)
            OnboardingGhostButton(title: "Skip") {
                viewModel.complete()
            }
            .accessibilityIdentifier(A11yID.Onboarding.skipName)
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .onAppear { isFocused = true }
    }
}

#Preview {
    ZStack {
        GradientBackground(center: .top)
        OnboardingNameView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build**

```bash
make build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Onboarding/OnboardingNameView.swift Baseline.xcodeproj
git commit -m "feat: onboarding name entry page"
```

---

### Task 8: Flow container

**Files:**
- Create: `Baseline/Views/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Create the container**

Create `Baseline/Views/Onboarding/OnboardingFlow.swift`:

```swift
import SwiftUI

/// First-launch onboarding container — paged Welcome → Name flow.
/// `BaselineApp` presents this instead of `MainTabView` until the
/// "hasCompletedOnboarding" flag is set. The flag is written by
/// `OnboardingViewModel` (any exit path) and observed by the app root via
/// @AppStorage, which is what swaps this flow out — there is no explicit
/// dismiss here.
struct OnboardingFlow: View {
    private enum Page {
        case welcome
        case name
    }

    @State private var viewModel = OnboardingViewModel()
    @State private var page: Page = .welcome

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            switch page {
            case .welcome:
                OnboardingWelcomeView(
                    onGetStarted: {
                        withAnimation(.snappy) { page = .name }
                    },
                    onSkip: { viewModel.complete() }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            case .name:
                OnboardingNameView(viewModel: viewModel)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    OnboardingFlow()
}
```

- [ ] **Step 2: Build**

```bash
make build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Onboarding/OnboardingFlow.swift Baseline.xcodeproj
git commit -m "feat: onboarding flow container with paged welcome→name transition"
```

---

### Task 9: `LaunchConfiguration.forceOnboarding` (TDD)

**Files:**
- Modify: `Baseline/App/LaunchConfiguration.swift`
- Modify: `BaselineTests/App/LaunchConfigurationTests.swift`

Why: every existing UI test expects `MainTabView` at launch, so onboarding must be suppressed under `-UITestMode`. The new onboarding UI test needs the opposite — a dedicated `-UITestShowOnboarding` argument forces the flow.

- [ ] **Step 1: Write the failing tests**

Append inside the class in `BaselineTests/App/LaunchConfigurationTests.swift`:

```swift
    func testForceOnboardingFlagDefaultsToFalse() {
        let config = LaunchConfiguration(arguments: ["app", "-UITestMode"], environment: [:])
        XCTAssertFalse(config.forceOnboarding)
    }

    func testForceOnboardingFlagParsed() {
        let config = LaunchConfiguration(
            arguments: ["app", "-UITestMode", "-UITestShowOnboarding"], environment: [:])
        XCTAssertTrue(config.forceOnboarding)
    }
```

- [ ] **Step 2: Run to verify failure**

Fast loop with `-only-testing:BaselineTests/LaunchConfigurationTests`.
Expected: build failure — `no member 'forceOnboarding'`.

- [ ] **Step 3: Implement**

In `Baseline/App/LaunchConfiguration.swift`, add to the stored properties:

```swift
    /// UI-test override: present onboarding even though `-UITestMode`
    /// normally suppresses it. Used only by OnboardingFlowUITests.
    let forceOnboarding: Bool
```

And in `init`, after `self.isUITesting = uiTesting`:

```swift
        self.forceOnboarding = arguments.contains("-UITestShowOnboarding")
```

- [ ] **Step 4: Run to verify pass**

Same command. Expected: all `LaunchConfigurationTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add Baseline/App/LaunchConfiguration.swift BaselineTests/App/LaunchConfigurationTests.swift
git commit -m "feat: -UITestShowOnboarding launch argument → forceOnboarding"
```

---

### Task 10: Root gating in `BaselineApp`

**Files:**
- Modify: `Baseline/BaselineApp.swift`

- [ ] **Step 1: Add the flag and the branch**

In `Baseline/BaselineApp.swift`:

(a) Below `@State private var appState: AppState`, add:

```swift
    /// First-launch gate. @AppStorage so completing onboarding (which writes
    /// the flag) reactively swaps the root to MainTabView.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Onboarding shows on first launch only. Under UI testing it is
    /// suppressed (the suite expects MainTabView) unless the dedicated
    /// -UITestShowOnboarding argument forces it.
    private var shouldShowOnboarding: Bool {
        guard !hasCompletedOnboarding else { return false }
        let config = LaunchConfiguration.current
        return !config.isUITesting || config.forceOnboarding
    }
```

(b) In `init()`, inside the `#if DEBUG / if config.isUITesting` block, right after the `TestDataSeeder.seed(...)` line, add:

```swift
            // Onboarding UI tests must start clean every run: a prior run's
            // completion writes persist in the simulator's standard defaults.
            if config.forceOnboarding {
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                UserDefaults.standard.removeObject(forKey: "userName")
            }
```

(c) In `body`, wrap the root in the branch — replace the current `WindowGroup` content:

```swift
    var body: some Scene {
        WindowGroup {
            Group {
                if shouldShowOnboarding {
                    OnboardingFlow()
                } else {
                    MainTabView()
                        .environment(appState)
                        .task {
                            guard !LaunchConfiguration.current.isUITesting else { return }
                            try? Tips.configure([
                                .displayFrequency(.weekly)
                            ])
                        }
                        .task {
                            guard !LaunchConfiguration.current.isUITesting else { return }
                            await HealthKitManager.requestAuthorizationIfNeeded()
                        }
                        .task {
                            guard !LaunchConfiguration.current.isUITesting else { return }
                            await mirror.reconcile(context: modelContainer.mainContext)
                        }
                }
            }
            .animation(.snappy, value: hasCompletedOnboarding)
        }
        .modelContainer(modelContainer)
    }
```

(The three `.task` blocks stay attached to `MainTabView` — they fire when onboarding completes and the branch swaps, exactly as on a normal launch.)

- [ ] **Step 2: Build and smoke-check both paths in the simulator**

```bash
make build
```

Expected: BUILD SUCCEEDED. Then verify behavior (this is the one task worth a manual run): fresh-install the app in a simulator (delete app first) → onboarding shows; complete it with a name → MainTabView appears and the Now screen greets by name; relaunch → straight to MainTabView.

- [ ] **Step 3: Run the existing UI smoke suite to prove suppression works**

```bash
set -o pipefail && xcodebuild test \
  -project Baseline.xcodeproj -scheme Baseline -testPlan Baseline-UITests \
  -destination "platform=iOS Simulator,name=$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+ Pro' | grep -v Max | grep -oE 'iPhone [0-9]+ Pro' | head -n1)" \
  -derivedDataPath .build/DerivedData \
  -only-testing:BaselineUITests/SmokeNavigationUITests | xcbeautify
```

Expected: PASS — UI tests still land on MainTabView, untouched by onboarding.

- [ ] **Step 4: Commit**

```bash
git add Baseline/BaselineApp.swift
git commit -m "feat: gate first launch behind onboarding flow (suppressed under UI testing)"
```

---

### Task 11: Onboarding UI tests

**Files:**
- Modify: `BaselineUITests/BaseUITestCase.swift`
- Create: `BaselineUITests/OnboardingFlowUITests.swift`

- [ ] **Step 1: Add the launch-argument hook to the base class**

In `BaselineUITests/BaseUITestCase.swift`, below the `seedProfile` property, add:

```swift
    /// Extra launch arguments appended by subclasses (e.g. onboarding tests
    /// pass -UITestShowOnboarding). Default: none.
    var extraLaunchArguments: [String] { [] }
```

And change the launch line in `setUpWithError`:

```swift
        app.launchArguments = ["-UITestMode", "-UITestSeed", seedProfile.rawValue]
            + extraLaunchArguments
```

- [ ] **Step 2: Write the onboarding UI tests**

Create `BaselineUITests/OnboardingFlowUITests.swift`:

```swift
import XCTest

/// End-to-end onboarding walk. -UITestShowOnboarding forces the flow under
/// UI testing AND clears the completion flag + name at launch (see
/// BaselineApp.init), so each test starts from a clean first-launch state.
@MainActor
final class OnboardingFlowUITests: BaseUITestCase {
    override var extraLaunchArguments: [String] { ["-UITestShowOnboarding"] }

    func testCompleteOnboardingWithNameLandsOnMainTabs() {
        let getStarted = app.buttons[A11yID.Onboarding.getStarted]
        XCTAssertTrue(getStarted.waitForExistence(timeout: Self.defaultTimeout),
                      "Welcome page should present on forced-onboarding launch")
        getStarted.tap()

        let nameField = app.textFields[A11yID.Onboarding.nameField]
        XCTAssertTrue(nameField.waitForExistence(timeout: Self.defaultTimeout))
        nameField.tap()
        nameField.typeText("Ben")
        app.buttons[A11yID.Onboarding.continueButton].tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: Self.defaultTimeout),
                      "Completing onboarding should land on the main tab bar")
    }

    func testSkipForNowLandsOnMainTabs() {
        let skip = app.buttons[A11yID.Onboarding.skipForNow]
        XCTAssertTrue(skip.waitForExistence(timeout: Self.defaultTimeout))
        skip.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: Self.defaultTimeout),
                      "Skipping onboarding should land on the main tab bar")
    }

    func testSkipOnNamePageLandsOnMainTabs() {
        app.buttons[A11yID.Onboarding.getStarted].tap()

        let skipName = app.buttons[A11yID.Onboarding.skipName]
        XCTAssertTrue(skipName.waitForExistence(timeout: Self.defaultTimeout))
        skipName.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: Self.defaultTimeout))
    }
}
```

- [ ] **Step 3: Run the new suite**

```bash
set -o pipefail && xcodebuild test \
  -project Baseline.xcodeproj -scheme Baseline -testPlan Baseline-UITests \
  -destination "platform=iOS Simulator,name=$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+ Pro' | grep -v Max | grep -oE 'iPhone [0-9]+ Pro' | head -n1)" \
  -derivedDataPath .build/DerivedData \
  -only-testing:BaselineUITests/OnboardingFlowUITests | xcbeautify
```

Expected: 3 tests PASS. (Run `make generate` first since a UI-test file was added. The test plans select whole targets, so new classes are picked up automatically.)

- [ ] **Step 4: Commit**

```bash
git add BaselineUITests/BaseUITestCase.swift BaselineUITests/OnboardingFlowUITests.swift Baseline.xcodeproj
git commit -m "test: end-to-end onboarding UI tests via -UITestShowOnboarding"
```

---

### Task 12: Developer re-trigger row

**Files:**
- Modify: `Baseline/Views/Settings/SettingsDeveloperSection.swift`

- [ ] **Step 1: Add the row**

In `SettingsDeveloperSection.swift`, after the "Clear All Data" `Button { … }` block and before the `Text("Debug build only…")` caption, add:

```swift
            SettingsDivider()
            Button {
                // Clearing the flag flips BaselineApp's @AppStorage-driven
                // root back to OnboardingFlow immediately.
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            } label: {
                SettingsRow(
                    icon: "sparkles",
                    label: "Show Onboarding Again",
                    value: nil,
                    style: .action
                )
            }
            .accessibilityIdentifier(A11yID.Settings.showOnboardingAgain)
```

- [ ] **Step 2: Build, then verify by hand**

```bash
make build
```

Expected: BUILD SUCCEEDED. In the simulator: Settings → Developer → Show Onboarding Again → the root swaps straight to the welcome page.

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Settings/SettingsDeveloperSection.swift
git commit -m "feat: debug re-trigger for onboarding in Settings developer section"
```

---

### Task 13: Remove vestigial Height/Age/Gender from Settings

**Files:**
- Delete: `Baseline/Views/Settings/HeightPickerView.swift`
- Delete: `Baseline/Views/Settings/BirthdayPickerView.swift`
- Delete: `Baseline/Views/Settings/GenderPickerView.swift`
- Modify: `Baseline/Views/Settings/SettingsView.swift`
- Modify: `Baseline/ViewModels/SettingsViewModel.swift`
- Modify: `BaselineTests/Snapshots/SettingsViewSnapshotTests.swift`

- [ ] **Step 1: Verify the reference inventory is still accurate**

```bash
grep -rn "HeightPickerView\|BirthdayPickerView\|GenderPickerView\|heightFeet\|heightInches\|heightCm\|birthdayInterval\|Gender(\|\.gender\|heightDisplay\|ageDisplay\|genderDisplay" --include='*.swift' . | grep -v ".build/"
```

Expected hits ONLY in: the three doomed view files, `SettingsView.swift` (profile section), `SettingsViewModel.swift`, `SettingsViewSnapshotTests.swift`. If anything else appears, STOP and re-assess before deleting.

- [ ] **Step 2: Trim the profile section in `SettingsView.swift`**

Replace the entire `profileSection` computed property with:

```swift
    private var profileSection: some View {
        SettingsSectionView(title: "PROFILE") {
            NavigationLink {
                NameEditView(viewModel: vm)
            } label: {
                SettingsRow(
                    icon: "person",
                    label: "Name",
                    value: vm.name.isEmpty ? nil : vm.name,
                    style: .push
                )
            }
        }
    }
```

- [ ] **Step 3: Strip the orphans from `SettingsViewModel.swift`**

Delete, in this order (all are now referenced by nothing):

1. The whole `// MARK: - Gender` block (the `Gender` enum, lines at the top of the file).
2. Version counters: `_heightFeetVersion`, `_heightInchesVersion`, `_heightCmVersion`, `_birthdayVersion`, `_genderVersion`.
3. Properties: `heightFeet`, `heightInches`, `heightCm`, `birthday`, `gender`.
4. The `convertHeight(from:to:)` method, and simplify the `lengthUnit` setter to:

```swift
    var lengthUnit: String {
        get { _ = _lengthUnitVersion; return defaults.string(forKey: "lengthUnit") ?? "in" }
        set { defaults.set(newValue, forKey: "lengthUnit"); _lengthUnitVersion += 1 }
    }
```

5. Computed properties: `age`, `heightDisplay`, `ageDisplay`, `genderDisplay`.

KEEP the `deleteAllData` keys array exactly as-is (still listing `"heightFeet"`, `"birthdayInterval"`, `"gender"`, …) — it clears legacy values for users who set them before this removal. Add this comment above the array:

```swift
        // Includes legacy profile keys (height/birthday/gender) so users who
        // set them before the fields were removed still get a clean wipe.
```

- [ ] **Step 4: Delete the three editor files and regenerate**

```bash
git rm Baseline/Views/Settings/HeightPickerView.swift \
       Baseline/Views/Settings/BirthdayPickerView.swift \
       Baseline/Views/Settings/GenderPickerView.swift
make generate
```

- [ ] **Step 5: Clean the snapshot-test seeding**

In `BaselineTests/Snapshots/SettingsViewSnapshotTests.swift`, delete these lines from the defaults setup (the keys no longer drive any UI):

```swift
        defaults.set(5, forKey: "heightFeet")
        defaults.set(10, forKey: "heightInches")
        defaults.set("male", forKey: "gender")
        // Birthday: May 15, 1992
        let birthday = Calendar.current.date(from: DateComponents(year: 1992, month: 5, day: 15))!
        defaults.set(birthday.timeIntervalSince1970, forKey: "birthdayInterval")
```

Do NOT re-record the reference PNG (issue #79; suite is excluded from CI).

- [ ] **Step 6: Build and run the logic tests**

```bash
make build
```

Then fast loop with `-only-testing:BaselineTests` (whole logic target — the deletion's blast radius is wide enough to justify it).
Expected: BUILD SUCCEEDED; all non-snapshot logic tests PASS. (If the compiler flags a missed `Gender`/height reference, the Step 1 grep lied — fix the straggler the same way.)

- [ ] **Step 7: Commit**

```bash
git status --short   # confirm: 3 deletions, 3 modifications, project file — nothing else
git add -A
git commit -m "refactor: remove vestigial Height/Age/Gender profile fields

Nothing in the app reads them — BMI/BMR/SMI come off the InBody printout.
Stored UserDefaults values are left in place (cleared by Delete All Data)."
```

---

### Task 14: Honest help text in `NameEditView`

**Files:**
- Modify: `Baseline/Views/Settings/NameEditView.swift`

- [ ] **Step 1: Fix the copy**

Replace:

```swift
                Text("Your name appears on widgets and export files.")
```

with:

```swift
                Text("Your name personalizes your greeting on the Now screen.")
```

- [ ] **Step 2: Build**

```bash
make build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Settings/NameEditView.swift
git commit -m "fix: NameEditView help text describes the real use (Now-screen greeting)"
```

---

### Task 15: Final verification & PR

- [ ] **Step 1: Full gate**

```bash
make generate && make lint && make test
```

Expected: lint clean under `--strict`; `Baseline-CI` plan fully green (logic + UI tests, including the three new `OnboardingFlowUITests`).

- [ ] **Step 2: Clean-tree check**

```bash
git status --short
```

Expected: empty. If anything is modified/untracked, a task's scoped `git add` missed it — resolve before pushing.

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feat/onboarding-5-welcome-name
gh pr create \
  --title "feat: first-launch onboarding + Now-screen greeting; remove vestigial profile fields (#5)" \
  --body "$(cat <<'EOF'
Closes #5.

## What
- **First-launch onboarding** (Welcome → Name), every step skippable, gated on a `hasCompletedOnboarding` flag. Suppressed under UI testing; `-UITestShowOnboarding` forces it for the new E2E tests. Debug re-trigger in Settings → Developer.
- **Personalized greeting on Now** — time-aware salutation, top-centered (approved mock variant B), degrades cleanly with no name. Logic in pure `Greeting` helper + `NowViewModel` with injectable clock.
- **Removed vestigial profile fields** (Height/Age/Gender) — nothing in the app reads them; their Settings help text claimed uses that don't exist. Stored values untouched (cleared by Delete All Data). Name's help text corrected.

## Spec & mocks
- `docs/superpowers/specs/2026-06-09-onboarding-flow-design.md`
- `docs/mockups/onboarding-*-APPROVED-*.html`, `docs/mockups/now-greeting-APPROVED-variant-b-2026-06-09.html`

## Notes for review
- **Existing users will see onboarding once** after updating (flag defaults false) — accepted in the spec (§8), two skippable screens.
- NowView/SettingsView **snapshot references not re-recorded** — environment mismatch tracked in #79; suites are excluded from the CI gate.
- Removing visible Settings fields is a deliberate user-facing change — release notes should mention it.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Confirm CI is green before merging.**

---

## Self-review (done at planning time)

- **Spec coverage:** §3 flow → Tasks 4–11; §4 greeting → Tasks 1–3; §5 cleanup/copy → Tasks 13–14; §6 tests/a11y → Tasks 1, 2, 4, 5, 9, 11; §8 risks → existing-user note in PR body, reference-inventory grep in Task 13 Step 1.
- **Type consistency:** `OnboardingViewModel.completeSavingName()/complete()` used identically in Tasks 4, 7, 8; `A11yID.Onboarding.*` names match between Tasks 5, 6, 7, 11; `forceOnboarding` matches between Tasks 9, 10, 11; `NowViewModel(modelContext:now:)` matches Tasks 2, 3.
- **Known deferred items (deliberate, not placeholders):** snapshot re-records (issue #79), release-notes mention (ships with the release, not this PR).
