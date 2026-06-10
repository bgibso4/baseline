# Onboarding Flow — Design (Issue #5, reframed)

**Date:** 2026-06-09
**Issue:** #5 — "Add lightweight onboarding flow (name, height, age, optional)" (`phase-4-ship`)
**Status:** Awaiting user review

---

## 1. Context & rationale

Issue #5 originally asked for a first-launch flow collecting **name, height, age** (gender optional) on the premise that profile data improves scan accuracy. During brainstorming we audited the actual consumers of these fields and found the premise is obsolete:

- **Nothing in the app computes from profile data.** BMI, BMR, and SMI are parsed off the InBody printout by OCR or typed into the scan review form (`ScanReviewForm.swift`). There is no `weight/height²` anywhere — the InBody device computes everything; the app records it.
- **Every profile field is vestigial**, and the Settings help text claims uses that don't exist:

  | Field | Read by anything? | Help text claims |
  |-------|-------------------|------------------|
  | Height | nowhere | "Used for BMR and SMI calculations on InBody scans." (`HeightPickerView.swift:67`) |
  | Birthday/Age | nowhere | (age-aware BMR) |
  | Gender | nowhere | "Used for BMR estimation and other gender-aware metric calculations." (`GenderPickerView.swift:42`) |
  | Name | one snapshot test only | "Your name appears on widgets and export files." (`NameEditView.swift:51`) — widgets and CSV export do **not** read it |

So this feature is reframed: **onboarding collects only Name**, and Name gets a *real* consumer — a personalized greeting on the Now screen. The dishonest help text is corrected, and the orphaned fields are removed.

## 2. Decisions (brainstormed 2026-06-08/09, mock-driven)

All visual decisions were made against high-fidelity mockups using production design tokens (bg `#0B0B0E`, card `#17171B`, accent `#6B7B94`, Exo 2 headings + SF body). Mockups persisted under `.superpowers/brainstorm/`.

| Decision | Choice | Alternatives rejected |
|----------|--------|----------------------|
| Flow paradigm | **Paged wizard** (full-screen pages, page dots) | Single setup screen; checklist hub |
| Welcome screen | **Warm greeting** — conversational, left-aligned, sets expectations ("a few seconds, skip any of it"), explicit "Skip for now" ghost button | Brand hero; value/feature intro |
| Scope | **Welcome + Name only** | Full name/height/age wizard (fields are vestigial) |
| Age entry style | (moot — age step cut) Date wheel had been chosen over calendar | — |
| Now-screen greeting placement | **B — top-centered**, mirroring the symmetric hero | A — top-left header; C — nav-bar title |
| Orphaned Height/Age/Gender fields | **Remove entirely** from Settings | Keep with corrected copy; defer |
| Name in CSV exports | **No** — fix the help text instead | Add name to exports (PII in shared files) |

## 3. Onboarding flow

Two full-screen pages, presented before `MainTabView` on first launch.

### Page 1 — Welcome

- Conversational, left-aligned: "Let's set you up" tone; subline sets expectations — short, optional, skippable.
- EKG mark (current single-stroke icon art). No wordmark dependency (wordmark lettering is still WIP per logo workstream).
- **Get started** (primary, accent `#606E85` button) → page 2.
- **Skip for now** (ghost button) → completes onboarding immediately.

### Page 2 — Name

- Single text field, visual language borrowed from `NameEditView` (but a fresh onboarding-native screen — the Settings editor bakes in its own NavigationStack + Cancel/Save toolbar and is not reused directly).
- **Continue** → saves to the existing `userName` UserDefaults key via `SettingsViewModel` → completes onboarding.
- **Skip** → completes onboarding without writing anything.
- No validation gates; empty name + Continue behaves like Skip.

### Gating & lifecycle

- `@AppStorage("hasCompletedOnboarding")` flag; checked at the root in `BaselineApp.swift`. Root branches: onboarding flow vs `MainTabView`. No flicker: the flag is synchronous UserDefaults, read before first frame.
- **UI-test suppression:** when `LaunchConfiguration.isUITesting`, onboarding never presents (treated as completed). The existing UI-test suite (which expects `MainTabView` on launch) is untouched. Precedent: several `.task` blocks already guard on this flag.
- Completing onboarding (any path: Skip for now, Continue, Skip) sets the flag once. There is no partial-resume state — the flow is short enough that re-showing from the start would be acceptable, but the flag is set on completion of either page's exit action, so abandonment mid-flow (app kill on page 2) re-shows the flow on next launch. That is acceptable and simpler than checkpointing.
- **Re-trigger:** "Show onboarding again" row in `SettingsDeveloperSection` (debug builds only) that clears the flag, per the issue's nice-to-have.

## 4. Now-screen greeting (Name's payoff)

- **Placement:** top-centered above the hero arc on `NowView` (decision B). The hero (arc, weight, stats, Weigh In) is unchanged — this is an addition to the top of the layout, not a re-flow. Note: `NowView` matches an APPROVED mockup (`docs/mockups/today-APPROVED-*.html`); the greeting placement was itself mock-approved on the real layout, which satisfies that bar.
- **Content:** time-aware bucket — "Good morning" / "Good afternoon" / "Good evening" — with the name on a second line when set.
- **Graceful degradation:** no name → greeting line only. Never an empty "Hi, " or trailing comma.
- **Architecture:** time-bucketing and string composition live in a pure, injectable-clock helper (e.g. `Greeting.swift` value type: `Greeting(date:name:)` → display strings), unit-testable without SwiftUI. The view renders it; no logic in the view body.

## 5. Settings cleanup (orphan removal + honest copy)

**Delete:**

- `Baseline/Views/Settings/HeightPickerView.swift`
- `Baseline/Views/Settings/BirthdayPickerView.swift`
- `Baseline/Views/Settings/GenderPickerView.swift`
- Their rows/navigation links in `SettingsView.swift`
- `SettingsViewModel` orphans: `heightFeet`, `heightInches`, `heightCm`, `birthday`, `gender`, the ft/in↔cm sync logic, and their version counters
- Any A11yID cases, unit tests, and snapshot/UI-test references touching the three editors (inventory at planning time)
- `Gender` model type if nothing else references it (verify at planning time)

**Keep:**

- Stored UserDefaults values (`heightFeet`, `birthdayInterval`, `gender`, …) are simply never read again. No deletion, no migration — harmless stale keys, and reversible if a future feature wants them.

**Fix copy:**

- `NameEditView.swift:51` help text → describe the real use: the greeting on the Now screen. (Final microcopy at implementation; something like "Your name personalizes your greeting on the Now screen.")

**Regeneration:** file deletions require `make generate` (XcodeGen) before build/commit.

## 6. Tests & accessibility

- **Unit (logic plan, no simulator):**
  - Greeting time-bucketing boundaries (morning/afternoon/evening edges, injected clock).
  - Greeting composition with/without a name (no dangling punctuation).
  - Onboarding completion writes `hasCompletedOnboarding`; name save path writes `userName` via `SettingsViewModel`.
- **UI:**
  - New `A11yID.Onboarding` cases for every interactive control: get-started, skip-for-now, name field, continue, skip — `IdentifierCoverageUITests` enforces presence.
  - One UI test launching *without* the standard UI-testing fast-path so onboarding presents: walk Welcome → Name → land on `MainTabView`. (Mechanism: a dedicated launch argument that allows onboarding while keeping other test isolation — exact shape decided at planning time against `LaunchConfiguration`.)
  - Existing suite unaffected (suppression via `isUITesting`).
- **Snapshots:** `NowView` snapshot will change (greeting). Per the snapshot-env-drift note, local snapshot failures are not a regression signal; re-recording happens under issue #79's environment.

## 7. Out of scope

- Name in CSV exports (rejected — keeps PII out of shared files).
- Widgets reading the name.
- Height/age/gender data migration or deletion of stored values.
- Wordmark/launch-animation work (separate logo workstream).
- Collecting any new profile fields.

## 8. Risks & notes

- **Removing visible Settings fields is a user-facing regression** for anyone who entered height/birthday/gender. Accepted deliberately: the fields never did anything, and their help text was misleading. Release notes should mention the removal.
- The deleted editors may be referenced by tests/snapshots not inventoried here; the implementation plan must grep for all references (`HeightPickerView`, `BirthdayPickerView`, `GenderPickerView`, `birthdayInterval`, `Gender(`) before deleting.
- `hasCompletedOnboarding` defaults to false for **existing** users updating the app — they will see onboarding once. Mitigation options (e.g. seed the flag when weigh-ins already exist) decided at planning time; default stance is *show it once anyway* (it's two skippable screens and existing users get the greeting feature explained implicitly).
