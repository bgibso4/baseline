# Phase 1 — Testing / CI / Lint Foundation

**Date:** 2026-05-16
**Status:** Approved design — ready for implementation planning
**Scope:** Phase 1 of a multi-phase effort to adopt engineering-infrastructure best practices into Baseline.

---

## Context & motivation

Baseline is approaching App Store v1.0. It has a substantial automated test suite — ~33 logic-test files (Models, ViewModels, OCR, Health, Sync, Utilities) plus 7 snapshot tests (pointfree SnapshotTesting) — but **nothing runs those tests automatically**. They only execute when the developer manually runs them in Xcode. There is no CI, no linting, and no developer-tooling layer (no Makefile, no Brewfile, no commit hooks).

This effort was prompted by a request to study a sister project, **Beacon** (`~/projects/beacon`), and adopt its testing/CI/lint practices into Baseline.

**Research finding that reframes the effort:** Beacon's *test coverage* is actually weaker than Baseline's — Beacon has zero unit tests, one UI-test file, and no snapshot tests; its CI never builds or tests the iOS app at all. What Beacon does better is the **infrastructure and process layer**: SwiftLint with a pre-commit hook, a Makefile with iOS build/test/lint targets, a Brewfile pinning tooling, and XcodeGen discipline.

So the opportunity is not "copy Beacon's tests" — Baseline already has more. It is to adopt Beacon's infrastructure layer and, because Baseline already owns the test suite Beacon lacks, **wire that suite into CI** — which makes Baseline's setup better than Beacon's, not merely equal.

## Multi-phase plan (this spec covers Phase 1 only)

1. **Phase 1 (this spec)** — iOS CI, SwiftLint + pre-commit hook, Makefile + Brewfile.
2. **Phase 2 (separate spec, later)** — UI test target + accessibility-identifier registry + accessibility-audit tests, launch-argument test mode, docs/process discipline (DECISIONS.md, TECHNICAL_DEBT.md, CONTRIBUTING.md).
3. **#5 onboarding** — built afterward, under the full infrastructure, so onboarding is the proving ground for the Phase 2 UI-test harness.
4. **#41 / #42** — App Store guidelines audit and listing → submit.

Sequencing rationale: the new infrastructure should exist before the last big chunk of v1.0 feature code (onboarding) is written, so onboarding is built under the safety net rather than having the net retrofitted under it. This is a deliberate "do it right" ordering that delays launch over a "ship fast" ordering.

## Key decisions

| Decision | Choice | Why |
|---|---|---|
| Approach | Lean & native (no Fastlane, no Python `pre-commit` framework) | Lowest-dependency fit for a solo, iOS-only repo. Everything is Swift, shell, and make. |
| CI test scope | Logic tests in CI; snapshot tests stay local | Snapshot tests are pixel-sensitive to simulator/Xcode version; running them in CI invites false failures. References were recorded locally (named for iPhone 13 Pro); Baseline has already had to stabilize snapshots once (commit `069e14b`). |
| Pre-commit mechanism | Native git hook (`core.hooksPath`) | Avoids pulling a Python toolchain into an iOS-only repo just to manage one Swift hook. |
| SwiftLint adoption | Warning-level first, ratchet to `--strict` in a later pass | Strict on a never-linted ~40-file codebase right before release would be a disruptive cleanup detour. |
| Release automation (Fastlane etc.) | Out of scope — filed as issue #73 | Fastlane's real value is signing + App Store delivery, which belongs in a release-automation project, not the testing floor. |

## Out of scope (non-goals for Phase 1)

- UI test target, accessibility-identifier registry, accessibility-audit tests (Phase 2).
- Launch-argument test mode / mock injection (Phase 2).
- DECISIONS.md / TECHNICAL_DEBT.md / CONTRIBUTING.md (Phase 2).
- Release automation / Fastlane / TestFlight upload automation (issue #73).
- Running snapshot tests in CI.
- Migrating remaining XCTest files to Swift Testing.

---

## Section 1 — Makefile + Brewfile

CI and the git hook both invoke `make` targets, so the same commands run locally and in CI with no drift.

### `Brewfile` (repo root)

Pins the developer toolchain, installed via `brew bundle`:

- `swiftlint` — linter
- `xcbeautify` — formats `xcodebuild` output for human and CI readability
- `xcodegen` — regenerates the Xcode project from `project.yml`

(Improvement over Beacon, whose `doctor.sh` assumes SwiftLint is present but whose Brewfile never installs it.)

### `Makefile` (repo root)

| Target | Action |
|---|---|
| `setup` | `brew bundle`, then install the git hook via `git config core.hooksPath hooks` |
| `generate` | `xcodegen` |
| `build` | `xcodebuild build`, simulator destination, output piped through `xcbeautify` |
| `test` | Logic tests only — runs the `Baseline-CI` test plan. The fast everyday gate; identical to what CI runs. |
| `test-snapshots` | The 7 snapshot tests only |
| `test-all` | Logic + snapshot tests. Intended to be run before cutting a release. |
| `lint` | `swiftlint lint` |
| `format` | `swiftlint --fix` (autocorrect) |
| `sim` | Build + boot + install + launch on a simulator, using simulator auto-detection |
| `clean` | `xcodebuild clean` + remove DerivedData |

**Simulator auto-detection** (pattern lifted from Beacon's Makefile): resolve the target simulator in three tiers — first booted `iPhone … Pro`, else first available `iPhone … Pro`, else a hard-coded fallback device literal. Keeps `xcodebuild -destination` resilient locally and in CI.

`make test` runs exactly the CI test plan, so a green local `make test` predicts a green CI run.

---

## Section 2 — SwiftLint + pre-commit hook

### `.swiftlint.yml` (repo root)

Adapted from Beacon's config: ~40 opt-in rules, the `no_print` custom rule (warns on `print(` — use a logger), and line/file/function/type length limits.

**Lint scope:** `Baseline`, `BaselineWidgets`, **and `BaselineTests`** (the test code is held to the same standard, per explicit decision). `DerivedData` is excluded.

### Adoption is a ratchet, not a big bang

1. **Initial autocorrect commit:** run `swiftlint --fix` and commit the autocorrected changes on their own, so the churn is reviewable in isolation.
2. **Warning severity to start:** the config begins at warning severity — violations are visible but do not block commits or CI.
3. **Strict ratchet (separate later pass, not part of Phase 1 delivery):** a follow-up cleans the residual violations and flips the config to `--strict` (warnings become errors). At that point the pre-commit hook and CI lint become hard gates. That follow-up pass will likely also add per-path rule relaxations for `BaselineTests` (long test methods trip `function_body_length`, large test classes trip `type_body_length`, etc.).

### Pre-commit hook

A committed shell script at `hooks/pre-commit`, wired via `git config core.hooksPath hooks` (run by `make setup`). No Python framework.

Behavior:
- Runs on **staged `.swift` files only** — fast.
- **Blocks** the commit on: SwiftLint *error*-severity violations, merge-conflict markers, and files larger than 1 MB (guards against accidentally committing build artifacts or large binaries).
- **Warnings print but do not block** — until the strict ratchet, after which error-severity covers the previously-warning rules.
- Approximately 30 lines; predictable, no auto-fixing/auto-restaging.

---

## Section 3 — GitHub Actions CI + test plans + merge gate

### Test plans

Baseline's scheme currently runs the whole `BaselineTests` target with no test plan. Phase 1 introduces two `.xctestplan` files, referenced from the `Baseline` scheme via `project.yml` (XcodeGen `testPlans`):

- **`Baseline.xctestplan`** — all tests. The default plan; what Xcode's Cmd-U uses locally.
- **`Baseline-CI.xctestplan`** — excludes the 7 snapshot test classes (`BodyViewSnapshotTests`, `HistoryViewSnapshotTests`, `NowViewSnapshotTests`, `ScanEntrySnapshotTests`, `SettingsViewSnapshotTests`, `TrendsViewSnapshotTests`, `WeighInSheetSnapshotTests`). This is the plan `make test` and CI run.

### `.github/workflows/ci.yml`

- **Triggers:** pull requests targeting `main`, and pushes to `main`.
- **Concurrency:** group per branch with cancel-in-progress, so superseded runs are cancelled.
- **Runner:** a GitHub-hosted macOS image with Xcode 26.x selected (`xcode-select` / `xcodes`). Swift Package Manager dependencies cached via `actions/cache`. Exact runner image label pinned during implementation.
- **Steps:** `make lint` → `make test` (the `Baseline-CI` plan). `make test` builds the app, the widget extension (a dependency of the app target), and the test target, so a compile break anywhere fails CI.
- **Cost:** the repo is public, so macOS runner minutes are free.

### Lint in CI

CI runs `make lint`, but lint starts **non-blocking** (informational), consistent with the warning-level adoption. It becomes a hard gate in the same later follow-up that flips SwiftLint to `--strict`. Running lint in CI at all is an improvement over Beacon, whose lint runs only in the local pre-commit hook.

### Merge gate

Once the workflow is green, branch protection should be enabled on `main` to require the CI status check before merge. This is a GitHub repository setting (configurable via `gh api` or the web UI). Until it is enabled, CI is informational only.

---

## How we verify Phase 1 succeeded

- `make setup` on a clean machine installs tooling and the hook with no manual steps.
- `make test` passes locally and runs only the ~33 logic-test files (no snapshot tests).
- `make test-all` additionally runs the 7 snapshot tests.
- `make lint` runs and reports violations without error-ing out (warning-level).
- A commit containing a deliberate merge-conflict marker or a SwiftLint error is blocked by the pre-commit hook.
- A pull request against `main` triggers the CI workflow; the workflow builds the app + widget + test target and runs the logic test suite to completion.
- The CI run is visible as a status check on the PR.

## Follow-ups (explicitly deferred, not Phase 1 deliverables)

- Strict ratchet: residual-violation cleanup, flip `.swiftlint.yml` to `--strict`, make pre-commit and CI lint hard gates, add `BaselineTests` per-path rule relaxations.
- Enable branch-protection requiring the CI check (a one-time GitHub setting; can be done as soon as CI is green).
- Phase 2 and #5 per the multi-phase plan above.
