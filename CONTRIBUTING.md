# Contributing to Baseline

## Setup

```bash
make setup     # brew bundle (swiftlint, xcbeautify, xcodegen) + installs the git pre-commit hook
make generate  # regenerate Baseline.xcodeproj from project.yml (run after adding/removing files)
```

## Everyday commands

| Command | What it runs |
|---------|--------------|
| `make build` | Build the app for the simulator |
| `make test` | Logic + UI tests (the `Baseline-CI` plan — exactly what CI runs) |
| `make test-ui` | UI tests only (`Baseline-UITests` plan) |
| `make test-snapshots` | Snapshot tests only |
| `make test-all` | Everything (logic + UI + snapshots) |
| `make lint` / `make format` | SwiftLint check / autocorrect |
| `make sim` | Build, boot, install, and launch on a simulator |

## Pre-commit hook

`make setup` points `core.hooksPath` at `hooks/`. The hook blocks a commit on SwiftLint *errors*, merge-conflict markers, and files larger than 1 MB. Never bypass it with `--no-verify` — fix the underlying issue.

## Test plans

- `Baseline.xctestplan` — all tests (local Cmd-U / default scheme plan).
- `Baseline-CI.xctestplan` — logic + UI tests; the 7 snapshot classes are skipped (pixel-sensitive to simulator/Xcode version). **This is the CI gate.**
- `Baseline-UITests.xctestplan` — UI tests only.
- `Baseline-Snapshots.xctestplan` — snapshot tests only.

Snapshot tests stay out of CI because their references are recorded against a specific simulator/Xcode and produce false diffs elsewhere. Run `make test-snapshots` locally before a release.

## UI testing & the accessibility-identifier convention

UI tests launch the app in a deterministic test mode: `-UITestMode -UITestSeed <empty|populated|goalActive>`. In this mode the app uses an in-memory, CloudKit-free SwiftData store seeded with fixed fixtures, and animations are disabled. The seam is `Baseline/App/LaunchConfiguration.swift`; seeding is `TestDataSeeder.seed(profile:into:referenceDate:)`.

**Every interactive control gets an accessibility identifier** from `Baseline/Accessibility/A11yID.swift`:

```swift
Button("Save") { … }
    .accessibilityIdentifier(A11yID.WeighIn.save)
```

This is enforced by `IdentifierCoverageUITests` — an untagged button fails the UI-test suite. When you add a control, add an `A11yID` case (named `screen.element`) and tag it in the same change. UI tests reference controls by these identifiers and navigate tabs by label (SwiftUI tab identifiers don't reach the tab bar buttons — see `BaseUITestCase.tapTab`).

## Branch & PR flow

Work on a feature branch; CI (`Build & Test`) must be green before merge. Do not push to `main` directly.
