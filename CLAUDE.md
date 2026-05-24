# Baseline — Engineering Guide

Baseline is a production iOS app (SwiftUI + MVVM, SwiftData, HealthKit, CloudKit sync, on-device OCR). It ships to real users. **Hold every change to a Principal-Engineer bar: code you would be proud to put your name on in a review at Amazon or Google.**

This file is the contract for *how* we build here. Read it before touching code.

---

## The bar

We are not writing code to make a linter pass. We are building software that is **correct, modular, extensible, and obvious to the next engineer** (often a future you, or Claude with none of today's context). When a choice is between "fast to type" and "right," choose right. When you can't, say so explicitly and leave a note — never silently take on debt.

If you find yourself fighting the design to make a change, the design is wrong. Stop and fix the boundary, don't pile onto the mess. The reason this guide exists is that several files grew past 1,000 lines before anyone pushed back (see issue #80). That happens one "just add it here" at a time. Don't add the next one.

---

## SOLID, applied to this codebase

These are not abstractions — here is what each means concretely in a SwiftUI/MVVM app:

- **Single Responsibility** — A type does one thing. A `View` renders and routes user intent; it does *not* parse CSVs, talk to HealthKit, or run business rules. That belongs in a ViewModel, a service, or a pure helper. A file that holds five unrelated `View` structs is five files wearing a trench coat — split it. **Heuristic: if you can't summarize a type's job in one sentence without "and," it's doing too much.**
- **Open/Closed** — Extend behavior by adding types/cases, not by editing a growing `switch` or threading a 9th boolean parameter through a function. New scan source? New CSV column role? Add a conforming type, don't widen an existing one.
- **Liskov Substitution** — Conformances honor their protocol's contract. A `Parser` conformance that throws where callers expect a value, or returns empty where they expect a throw, is a landmine.
- **Interface Segregation** — Small, focused protocols. Don't force a caller to depend on (or stub, in tests) methods it never uses. Prefer several narrow protocols over one fat one.
- **Dependency Inversion** — ViewModels and services depend on protocols, not concrete singletons. This is what makes them testable without a simulator (see the logic-test plan). Inject collaborators; don't reach for `.shared` inside business logic.

---

## Modularity & file discipline

- **One primary type per file**, named after the file. Small, tightly-coupled helpers (a private struct used only by that type) may share the file; independent types get their own.
- **Size is a smell, not a rule.** SwiftLint thresholds (`.swiftlint.yml`) are a backstop, not a target. A 500-line file that does one thing well is fine; a 200-line type doing three things is not. But when a file crosses ~400 lines, treat it as a prompt to ask "what responsibilities have accreted here?"
- **Decompose along seams, not by line count.** When splitting an oversized file, find the *natural boundaries* (distinct screens, distinct parsing stages, distinct concerns) and give each its own file/type. Never split a function in half just to duck a threshold — that makes the code worse and the metric meaningless.
- **Pure logic should be pure.** Parsing, unit conversion, date handling, and import/merge rules should be free functions or value types with no UIKit/SwiftUI/HealthKit imports, so they can be unit-tested fast and reused.
- **Extensible by composition.** New behavior should slot in as a new type/file, leaving existing files untouched or barely touched. If adding a feature means editing six files, the boundaries are wrong.

---

## Definition of done (every change)

A change is not done until **all** of these hold — verify, don't assume:

1. **It works** — built and exercised, not just "looks right." For behavior changes, run the app or a test that proves it.
2. **It's tested** — new logic has unit tests (logic-test plan, no simulator needed); new UI controls have `A11yID` cases and are covered. A bug fix gets a regression test that fails without the fix.
3. **`make lint` passes** under `--strict` (warnings are hard gates) and **`make test` is green** (the `Baseline-CI` plan — exactly what CI runs).
4. **The project regenerates** — added/removed/moved files require `make generate` (XcodeGen globs by directory; new files in an existing folder are picked up automatically, but the project must be regenerated before build/commit).
5. **No silent debt** — if you relaxed a threshold, swallowed an error, or left a TODO, it's called out in the PR, not buried.

---

## Hard rules

- **Never `--no-verify`.** The pre-commit hook (SwiftLint errors, conflict markers, large files) is a floor. Fix the cause.
- **Never push to `main`.** Feature branch → green CI → PR. (See CONTRIBUTING.md.)
- **Never widen a lint threshold to avoid refactoring.** That is exactly the debt issue #80 exists to repay. If a real change genuinely needs more headroom, that's a conversation, not a quiet `.swiftlint.yml` edit.
- **Errors are observable.** Don't log failures only under `#if DEBUG` — production needs `Log.<category>.error(...)` so real-world failures aren't invisible. Don't swallow errors with `try?` where the caller needs to know.
- **Every interactive control gets an `A11yID`** (`Baseline/Accessibility/A11yID.swift`), added in the same change — enforced by `IdentifierCoverageUITests`.
- **No `print()`** — use the `Log` helper / `os.Logger` (custom lint rule enforces this).

---

## Architecture map

| Layer | Where | Responsibility |
|-------|-------|----------------|
| Views | `Baseline/Views/<Feature>/` | SwiftUI rendering + user-intent routing only |
| ViewModels | `Baseline/ViewModels/` | Presentation state & orchestration; testable without a simulator |
| Models | `Baseline/Models/` | SwiftData entities & domain types |
| Services | `Baseline/Health`, `Sync`, `OCR`, `Utilities` | I/O, parsing, system integration — protocol-fronted, injectable |
| Design | `Baseline/Design/` | Tokens, theming |

When unsure where code goes: if it imports SwiftUI, it's a View concern; if it makes decisions or talks to the outside world, it's a ViewModel/service concern; if it's a pure transformation, it's a helper. Keep the layers from leaking into each other.

---

## Commands

```bash
make setup     # one-time: tooling (swiftlint, xcbeautify, xcodegen) + pre-commit hook
make generate  # regenerate Baseline.xcodeproj from project.yml (after adding/removing files)
make build     # build for simulator
make test      # logic + UI tests — the Baseline-CI plan, the CI gate
make lint      # SwiftLint --strict (the gate); `make format` to autocorrect
```
