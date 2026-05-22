# Phase 2 — UI-Test Harness Foundation

**Date:** 2026-05-21
**Status:** Approved design — ready for implementation planning
**Scope:** Phase 2 of the multi-phase effort to adopt engineering-infrastructure best practices into Baseline (Phase 1 shipped CI + SwiftLint + Makefile/Brewfile in PR #74).

---

## Context & motivation

Phase 1 gave Baseline a CI gate that runs its logic test suite on every PR, plus SwiftLint, a pre-commit hook, and a Makefile/Brewfile developer layer. What it deliberately left for Phase 2 is the **UI-test layer**: there is no UI-test target, no way to launch the app in a deterministic test state, and no accessibility-identifier discipline.

The sequencing rationale (carried from the Phase 1 spec): build the UI-test harness **before** the last big chunk of v1.0 feature code — onboarding (#5) — so onboarding is built under the safety net rather than having the net retrofitted under it. Onboarding becomes the proving ground for this harness; Phase 2 itself proves the harness against the screens that exist today.

### Findings from exploration that shaped this design

1. **No UI-test target exists** in `project.yml`. Phase 2 adds `BaselineUITests`.
2. **The existing test-mode hooks are unit-test-only.** `ArcIndicatorView.swift:39` and `TrendsView.swift:1050` detect tests via the `XCTestConfigurationFilePath` / `XCTestBundlePath` environment variables. Those are set in the *app* process for unit tests, but **not** for the app process driven by UI tests (UI tests run in a separate runner process). So without a launch-argument test mode, UI tests would run with animations enabled and against the real SwiftData/CloudKit store — flaky and non-deterministic. A launch-arg mode is therefore load-bearing, not cosmetic.
3. **The "docs discipline" item partly already exists and partly conflicts with a stated preference.** `docs/DESIGN_DECISIONS.md` already serves as the decisions log. `docs/FUTURE_WORK.md` records that the backlog was moved to GitHub issues *because* flat markdown files "repeatedly drifted out of sync." A flat `TECHNICAL_DEBT.md` (as the original Phase 1 spec suggested) would reintroduce exactly that drift. So Phase 2 docs are scoped to `CONTRIBUTING.md` plus a `tech-debt` GitHub label, not new flat tracking files.
4. **`Baseline/Utilities/TestDataSeeder.swift` already exists** and can be extended for seed profiles rather than starting fresh.
5. **`BaselineApp.init()` (`Baseline/BaselineApp.swift:37-94`)** builds the `ModelContainer` from a CloudKit-backed config + a local-only config. This is the single integration point for the test-mode store branch.

---

## Key decisions

| Decision | Choice | Why |
|---|---|---|
| UI-test scope | Harness **plus** full end-to-end flow coverage of existing screens | User chose to invest in real flow tests now (weigh-in, scan entry, set-goal, CSV import), not just a thin smoke test. Onboarding adds its own flow tests later. |
| Test-mode data store | In-memory `ModelContainer` (`isStoredInMemoryOnly: true`, `cloudKitDatabase: .none`) seeded with deterministic fixtures | Each run starts identical and isolated; nothing touches iCloud or persists. A seed-profile arg varies the fixture for empty-state vs populated tests. |
| A11y registry | Single shared `A11yID` enum compiled into app **and** UI-test target; **exhaustively** tag every interactive control across all 5 screens | One source of truth, no stringly-typed drift. User chose exhaustive tagging now over tag-as-needed. |
| Test-mode seam | One centralized `LaunchConfiguration` type parsed once at launch | Replaces the two scattered `XCTestConfigurationFilePath` checks with a single typed, unit-testable seam instead of growing the stringly-typed env checks. |
| UI tests in CI | **Run in CI**, not local-only | Determinism is engineered in (animations off, in-memory seed, no CloudKit), so the flakiness rationale that keeps snapshot tests local does not apply. Running them in CI is the payoff of the harness. Public repo → free runner minutes. |
| Docs | `CONTRIBUTING.md` + a `tech-debt` GitHub label (migrate Phase 1 follow-ups into issues) | `DESIGN_DECISIONS.md` already exists; flat tracking files contradict the issues-over-markdown preference. |

## Out of scope (non-goals for Phase 2)

- Onboarding (#5) and its flow tests — built next, under this harness.
- SwiftLint strict-ratchet pass and CI hardening — Phase 1 deferred follow-ups, migrated to `tech-debt` issues in this phase but executed separately.
- Snapshot tests moving into CI — they remain local-only (Phase 1 decision stands).
- Migrating remaining XCTest unit files to Swift Testing.
- Performance/launch-time UI tests (`measure` blocks).

---

## Section 1 — `LaunchConfiguration` (the test-mode seam)

**File:** `Baseline/App/LaunchConfiguration.swift`

A value type that parses `ProcessInfo.processInfo.arguments` exactly once and exposes typed flags. A `static let current` is the single read point used across the app.

Fields:
- `isUITesting: Bool` — true when `-UITestMode` is present in the launch arguments.
- `seedProfile: SeedProfile` — parsed from `-UITestSeed <value>`; one of `.empty`, `.populated`, `.goalActive`. Defaults to `.populated` when UI-testing and no value given; `.empty`-equivalent (irrelevant) when not UI-testing.
- `shouldDisableAnimations: Bool` — true if `isUITesting` **or** the unit-test environment variables (`XCTestConfigurationFilePath` / `XCTestBundlePath`) are present.

Construction must accept an injected argument array and environment dictionary (so unit tests can feed scenarios without touching the real process). `current` is built from the real `ProcessInfo`.

**Refactor of existing call sites:** `ArcIndicatorView.swift:39-40` and `TrendsView.swift:1050-1052` stop reading the env vars directly and instead read `LaunchConfiguration.current.shouldDisableAnimations`. Behavior under unit tests is preserved (the env-var path still feeds the flag); UI tests now also disable animations via the launch arg.

**Tests (unit):** feed argument arrays — no args, `-UITestMode`, `-UITestMode -UITestSeed empty`, `-UITestSeed goalActive`, and an env dict with `XCTestConfigurationFilePath` set — and assert each derived flag.

---

## Section 2 — `BaselineApp` test-mode branch

**File:** `Baseline/BaselineApp.swift` (modify `init()`).

At the top of `init()`, read `LaunchConfiguration.current`. When `isUITesting` is true, take a separate container-construction path:

- Build a **single** `ModelConfiguration` for the full schema (`WeightEntry`, `Scan`, `Measurement`, `SyncState`, `Goal`) with `isStoredInMemoryOnly: true` and `cloudKitDatabase: .none`. No App Group URL, no CloudKit.
- Seed the `mainContext` via `TestDataSeeder` according to `seedProfile` **before** the preloaded view models are constructed, so the first render already reflects the fixture.
- **Skip** `CloudKitSyncMonitor.start()`, the HealthKit authorization `.task`, `Tips.configure`, and the mirror `reconcile` `.task` when UI-testing. (The mirror stays `NoOpOutboundMirror`, which it already is in the public build.)

The production path (app:42-73) is unchanged — the test branch is additive and fully contained behind `isUITesting`.

**Note on `.task` skips:** the three `body`-level `.task` modifiers (app:102-112) gain an `if !LaunchConfiguration.current.isUITesting` guard, or are wrapped so they no-op under test. HealthKit auth in particular must not prompt during UI tests.

---

## Section 3 — Seed profiles (extend `TestDataSeeder`)

**File:** `Baseline/Utilities/TestDataSeeder.swift` (extend).

Add a `SeedProfile` enum and a `seed(_ profile:into:)` entry point producing **deterministic** fixtures (fixed reference date, fixed values — no `Date()`/random):

- `.empty` — inserts nothing. Backs empty-state UI tests.
- `.populated` — a fixed run of daily `WeightEntry` records over a known window, one `Scan` with body-composition `Measurement`s, no active goal.
- `.goalActive` — everything in `.populated` plus one active `Goal` so Trends renders goal mode.

Fixtures use a frozen base date (a constant, e.g. a fixed `2026-01-01` anchor) so assertions on counts, extents, and displayed values are stable across runs and machines.

**Tests (unit):** seed each profile into an in-memory context and assert the resulting object counts and a couple of representative field values.

---

## Section 4 — A11y identifier registry

**File:** `Baseline/Accessibility/A11yID.swift` — compiled into **both** the `Baseline` app target and the `BaselineUITests` target (added to both target source lists in `project.yml`).

A namespace of nested enums of `String` raw values, one group per screen/area:

- `A11yID.TabBar` — `now`, `trends`, `body`, `history`, `settings`
- `A11yID.Now` — the weigh-in button, range toggle, stats elements
- `A11yID.WeighIn` — `stepperPlus`, `stepperMinus`, `valueLabel`, `save`, `cancel`
- `A11yID.Trends` — metric picker, window stepper controls, set-goal entry, goal-mode elements
- `A11yID.Body` — `scanButton` and scan list elements
- `A11yID.ScanEntry` — capture/manual-entry fields, confirm/save
- `A11yID.History` — list and row elements
- `A11yID.Settings` — toggles, the privacy/terms links, CSV import/export, about

**Exhaustive tagging:** every interactive control across all 5 screens gets `.accessibilityIdentifier(A11yID.…)`. This is a deliberate, complete pass — not tag-as-needed.

Identifiers are referenced by raw value from the UI tests (e.g. `app.buttons[A11yID.WeighIn.save]`), so a rename in one place flows to the tests at compile time.

---

## Section 5 — `BaselineUITests` target + tests

**`project.yml`:** add a `BaselineUITests` target, `type: bundle.ui-testing`, `platform: iOS`, `TARGETED_DEVICE_FAMILY: "1"`, depending on the `Baseline` target. Add it to the `Baseline` scheme's test action (via test plans, Section 6).

**`BaseUITestCase.swift`:** a shared `XCTestCase` subclass. `setUpWithError` sets `continueAfterFailure = false`, constructs `XCUIApplication()`, sets `launchArguments = ["-UITestMode", "-UITestSeed", "<profile>"]` (profile chosen per test class), and launches. Helpers for tab navigation by `A11yID.TabBar`.

Test files:

- **`AccessibilityAuditUITests.swift`** — navigates to each of the 5 screens and calls `try app.performAccessibilityAudit()` on each. Catches contrast, hit-target, label, and clipping issues automatically.
- **`SmokeNavigationUITests.swift`** — launches and visits all 5 tabs, asserting a landmark element exists on each. The minimum "the app boots and navigates" guarantee.
- **`IdentifierCoverageUITests.swift`** — the ratchet: walk `app.buttons`/`app.textFields` on each screen and fail if any non-system interactive element has an empty `identifier`. Catches future untagged controls (adapted from Beacon's `testNoUntaggedButtons`/`testNoUntaggedTextFields`, with a system-control allowlist).
- **`WeighInFlowUITests.swift`** — `.populated`: open the weigh-in sheet, use the steppers, save, assert the Now screen reflects the new value.
- **`ScanEntryFlowUITests.swift`** — `.populated`: drive the scan-entry **manual-entry** path (camera capture cannot run in the simulator), confirm, assert the new scan appears in Body/History.
- **`SetGoalFlowUITests.swift`** — `.populated`: set a goal from Trends, assert goal mode renders.
- **`CSVImportFlowUITests.swift`** — `.empty`: drive the CSV import flow and assert imported rows appear. (Import source fixture provided via the test bundle or the documents picker stub — resolved in planning.)

---

## Section 6 — Test plans + CI

**Test plans:**
- `Baseline.xctestplan` (all) — add the `BaselineUITests` target so local Cmd-U runs everything.
- New `Baseline-UITests.xctestplan` — the UI-test target only, for `make test-ui`.
- `Baseline-CI.xctestplan` — **add the UI-test target** so CI runs logic + UI tests. Snapshot classes remain skipped (unchanged).
- `Baseline-Snapshots.xctestplan` — unchanged.

**Makefile:** add `test-ui` (runs the `Baseline-UITests` plan). `make test` continues to run the `Baseline-CI` plan, which now includes UI tests, so a green local `make test` still predicts a green CI run.

**CI (`.github/workflows/ci.yml`):** no structural change required — it runs `make test`, which now includes the UI tests via the `Baseline-CI` plan. The job already runs on a booted simulator. (Watch run time; add a `timeout-minutes` guard — see the Phase 1 CI-hardening follow-up, which is being migrated to an issue in this phase anyway.)

---

## Section 7 — Docs

- **`CONTRIBUTING.md`** (repo root): developer setup and workflow reference — `make setup` (Brewfile + hooks), the pre-commit hook behavior, the test plans and what each runs, how to run UI tests (`make test-ui`), and the **A11y tagging convention**: every new interactive control gets an `A11yID` entry and the `.accessibilityIdentifier` modifier, enforced by `IdentifierCoverageUITests`.
- **`tech-debt` GitHub label** + issue migration: create the label and file issues for the Phase 1 deferred follow-ups (the SwiftLint strict-ratchet pass; the CI-hardening items — test-plan-sync assertion, `timeout-minutes`, SHA-pinning `setup-xcode`). This replaces a flat `TECHNICAL_DEBT.md`, consistent with the issues-over-markdown preference.

No `TECHNICAL_DEBT.md` and no `DECISIONS.md` are created — the latter already exists as `docs/DESIGN_DECISIONS.md`.

---

## How we verify Phase 2 succeeded

- Launching with `-UITestMode -UITestSeed populated` shows the seeded fixture, animations disabled, no iCloud/HealthKit activity.
- `make test-ui` runs only the UI tests; `make test` runs logic + UI tests (the CI plan); `make test-all` adds snapshots.
- `AccessibilityAuditUITests` passes `performAccessibilityAudit()` on all 5 screens.
- `IdentifierCoverageUITests` fails if an interactive control is added without an `A11yID`.
- The four flow tests (weigh-in, scan entry, set-goal, CSV import) pass deterministically across repeated runs.
- A PR triggers CI and the UI tests run as part of the gate.
- `CONTRIBUTING.md` lets a fresh checkout reach a green `make test` with no tribal knowledge.
- The `tech-debt` label exists and the Phase 1 follow-ups are filed as issues.

## Follow-ups (explicitly deferred, not Phase 2 deliverables)

- Onboarding (#5), built under this harness with its own flow tests.
- SwiftLint strict-ratchet pass and CI hardening — filed as `tech-debt` issues in this phase, executed separately.
- Enable branch protection on `main` requiring the CI check (one-time GitHub setting; can be done once UI tests are green in CI).
- Performance/launch-time UI tests, if wanted later.
