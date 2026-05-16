# Phase 1 — Testing / CI / Lint Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Baseline an engineering-infrastructure floor — GitHub Actions CI that runs the existing logic-test suite on every PR, SwiftLint with a native git pre-commit hook, and a Makefile + Brewfile developer-tooling layer.

**Architecture:** A `Makefile` defines every build/test/lint command. The CI workflow and the git pre-commit hook both call those make targets, so the same commands run locally and in CI with no drift. Logic tests and snapshot tests are separated via Xcode test plans; CI runs logic tests only (snapshot tests are pixel-sensitive to the rendering environment and stay local).

**Tech Stack:** GNU Make, Homebrew (Brewfile), SwiftLint, XcodeGen, xcbeautify, GitHub Actions (macOS runner), Xcode test plans (`.xctestplan`).

**Methodology note:** This is infrastructure work — there is no application logic to test-drive. Each task uses a *verify-by-running* pattern (create the artifact, run it, confirm the expected output) rather than red-green TDD.

**Before you start:** Do this work on a feature branch. From an up-to-date `main`:
```bash
git checkout main && git pull --ff-only && git checkout -b feat/phase-1-testing-ci
```
The branch is required — Task 7 verifies CI by opening a pull request.

**Spec:** `docs/superpowers/specs/2026-05-16-phase-1-testing-ci-foundation-design.md`

**Refinement vs. spec:** the spec describes two test plans (all, CI). This plan adds a third — `Baseline-Snapshots.xctestplan` — so `make test-snapshots` selects snapshot tests without hardcoding class names in the Makefile.

---

## Task 1: Brewfile + install tooling

**Files:**
- Create: `Brewfile`

- [ ] **Step 1: Create the Brewfile**

Create `Brewfile` at the repo root:

```ruby
# Developer tooling for Baseline. Install with `brew bundle` (or `make setup`).
brew "swiftlint"
brew "xcbeautify"
brew "xcodegen"
```

- [ ] **Step 2: Install the tooling**

Run: `brew bundle`
Expected: Homebrew installs (or reports already-installed) `swiftlint`, `xcbeautify`, `xcodegen`. Ends with `Homebrew Bundle complete!`.

- [ ] **Step 3: Verify each tool is on PATH**

Run: `swiftlint version && xcbeautify --version && xcodegen --version`
Expected: three version strings print, no "command not found".

- [ ] **Step 4: Commit**

```bash
git add Brewfile
git commit -m "build: add Brewfile pinning swiftlint, xcbeautify, xcodegen"
```

---

## Task 2: Makefile + .gitignore

**Files:**
- Create: `Makefile`
- Modify: `.gitignore`

- [ ] **Step 1: Create the Makefile**

Create `Makefile` at the repo root. **Recipe lines must be indented with a literal TAB**, not spaces — make requires it.

```makefile
# Baseline — developer tooling. Run targets from the repository root.
# See `make help`.

PROJECT      := Baseline.xcodeproj
SCHEME       := Baseline
DERIVED_DATA := $(CURDIR)/.build/DerivedData
BUNDLE_ID    := com.cadre.baseline

# Simulator auto-detection: booted iPhone Pro -> first available iPhone Pro -> fallback.
BOOTED_SIM  := $(shell xcrun simctl list devices booted 2>/dev/null | grep -oE 'iPhone [0-9]+ Pro' | head -n1)
AVAIL_SIM   := $(shell xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone [0-9]+ Pro' | head -n1)
SIM_DEVICE  := $(or $(BOOTED_SIM),$(AVAIL_SIM),iPhone 16 Pro)
DESTINATION := platform=iOS Simulator,name=$(SIM_DEVICE)

.PHONY: help setup generate build test test-snapshots test-all lint format sim clean

help:
	@echo "Baseline — make targets:"
	@echo "  setup           Install tooling (brew bundle) + configure git hooks"
	@echo "  generate        Regenerate Baseline.xcodeproj from project.yml"
	@echo "  build           Build the app for the simulator"
	@echo "  test            Run logic tests (Baseline-CI plan) — the CI gate"
	@echo "  test-snapshots  Run snapshot tests only (Baseline-Snapshots plan)"
	@echo "  test-all        Run all tests (Baseline plan)"
	@echo "  lint            Run SwiftLint"
	@echo "  format          Autocorrect with SwiftLint"
	@echo "  sim             Build, install, and launch on a simulator"
	@echo "  clean           Clean build output and DerivedData"
	@echo ""
	@echo "Simulator: $(SIM_DEVICE)"

setup:
	brew bundle
	git config core.hooksPath hooks
	@echo "Tooling installed and git hooks configured."

generate:
	xcodegen generate

build:
	set -o pipefail && xcodebuild build \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

test:
	set -o pipefail && xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -testPlan Baseline-CI \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

test-snapshots:
	set -o pipefail && xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -testPlan Baseline-Snapshots \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

test-all:
	set -o pipefail && xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -testPlan Baseline \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

lint:
	swiftlint lint

format:
	swiftlint --fix

sim: build
	@set -e; \
	UDID=$$(xcrun simctl list devices available | grep -E '$(SIM_DEVICE) \(' | grep -oE '[0-9A-Fa-f-]{36}' | head -n1); \
	if [ -z "$$UDID" ]; then echo "No simulator found for $(SIM_DEVICE)"; exit 1; fi; \
	xcrun simctl boot "$$UDID" 2>/dev/null || true; \
	open -a Simulator; \
	APP=$$(find $(DERIVED_DATA)/Build/Products -name 'Baseline.app' -type d | head -n1); \
	xcrun simctl install "$$UDID" "$$APP"; \
	xcrun simctl launch "$$UDID" $(BUNDLE_ID)

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) >/dev/null 2>&1 || true
	rm -rf $(DERIVED_DATA)
```

Note: the `test`, `test-snapshots`, `test-all`, and `lint`/`format` targets reference files created in Tasks 3 and 5. They are defined now but only verified in those later tasks. This task verifies `help`, `generate`, and `build` only.

- [ ] **Step 2: Add the build directory to .gitignore**

Append this line to `.gitignore`:

```
.build/
```

- [ ] **Step 3: Verify `make help`**

Run: `make help`
Expected: the target list prints, ending with a `Simulator: iPhone … Pro` line.

- [ ] **Step 4: Verify `make build`**

Run: `make build`
Expected: build runs through `xcbeautify` and ends with a success line (`Build Succeeded` / `** BUILD SUCCEEDED **`). If it fails, fix the Makefile before continuing — do not proceed.

- [ ] **Step 5: Commit**

```bash
git add Makefile .gitignore
git commit -m "build: add Makefile with build/test/lint/sim targets"
```

---

## Task 3: SwiftLint configuration

**Files:**
- Create: `.swiftlint.yml`

- [ ] **Step 1: Create the SwiftLint config**

Create `.swiftlint.yml` at the repo root:

```yaml
# SwiftLint configuration for Baseline.
# Adoption is a ratchet: this config starts LENIENT (warnings, not errors) so
# the initial rollout never blocks a commit or CI. A later follow-up pass will
# tighten severities and enable `--strict`. See
# docs/superpowers/specs/2026-05-16-phase-1-testing-ci-foundation-design.md

included:
  - Baseline
  - BaselineWidgets
  - BaselineTests

excluded:
  - .build
  - DerivedData
  - Baseline.xcodeproj

# Lenient start: rules that default to `error` are softened to `warning` so the
# initial adoption never blocks. The strict-ratchet follow-up removes these.
force_cast:
  severity: warning
force_try:
  severity: warning

# Length thresholds — warning only (no error threshold during the ratchet).
line_length:
  warning: 120
  ignores_comments: true
  ignores_urls: true
file_length:
  warning: 600
function_body_length:
  warning: 80
type_body_length:
  warning: 400
identifier_name:
  min_length: 2
  excluded: [id, db, x, y, to, vm]

disabled_rules:
  - todo

opt_in_rules:
  - array_init
  - closure_end_indentation
  - closure_spacing
  - collection_alignment
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - contains_over_first_not_nil
  - empty_collection_literal
  - empty_count
  - empty_string
  - explicit_init
  - fallthrough
  - fatal_error_message
  - first_where
  - flatmap_over_map_reduce
  - identical_operands
  - joined_default_parameter
  - last_where
  - legacy_random
  - literal_expression_end_indentation
  - lower_acl_than_parent
  - modifier_order
  - multiline_arguments
  - multiline_function_chains
  - multiline_parameters
  - operator_usage_whitespace
  - overridden_super_call
  - pattern_matching_keywords
  - prefer_self_type_over_type_of_self
  - redundant_nil_coalescing
  - redundant_type_annotation
  - sorted_first_last
  - toggle_bool
  - unneeded_parentheses_in_closure_argument
  - vertical_whitespace_closing_braces
  - yoda_condition

custom_rules:
  no_print:
    name: "No print()"
    regex: '\bprint\('
    message: "Use os.Logger / the app's Log helper instead of print()."
    severity: warning
```

- [ ] **Step 2: Verify `make lint` runs**

Run: `make lint`
Expected: SwiftLint runs and prints a violation summary (e.g. `Found N violations, 0 serious`). `0 serious` means no error-severity violations — the intended lenient state. The command should exit 0.

If the command exits non-zero, error-severity violations exist. Either fix them, or soften the offending rule to `severity: warning` in `.swiftlint.yml`. The goal of the lenient start is a clean (exit-0) `make lint`.

- [ ] **Step 3: Commit**

```bash
git add .swiftlint.yml
git commit -m "build: add SwiftLint config (lenient warning-level start)"
```

---

## Task 4: SwiftLint autocorrect pass

This task commits the mechanical `swiftlint --fix` churn on its own so it is reviewable in isolation, separate from the config commit.

**Files:**
- Modify: whatever `swiftlint --fix` autocorrects across `Baseline/`, `BaselineWidgets/`, `BaselineTests/`.

- [ ] **Step 1: Run the autocorrect**

Run: `make format`
Expected: SwiftLint applies autocorrections and reports the number of files corrected.

- [ ] **Step 2: Review the diff**

Run: `git diff --stat`
Expected: a list of modified Swift files with mechanical changes only (whitespace, modifier order, redundant annotations, etc.). Spot-check `git diff` on a couple of files to confirm no behavioral changes.

- [ ] **Step 3: Re-verify lint is clean**

Run: `make lint`
Expected: violation count is the same or lower than Task 3 Step 2, still `0 serious`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "style: apply swiftlint --fix autocorrections"
```

If `git diff --stat` in Step 2 showed no changes, skip this commit — there is nothing to autocorrect.

---

## Task 5: Test plans + scheme wiring

**Files:**
- Create: `Baseline.xctestplan`
- Create: `Baseline-CI.xctestplan`
- Create: `Baseline-Snapshots.xctestplan`
- Modify: `project.yml` (scheme `test` section)

- [ ] **Step 1: Confirm the BaselineTests target identifier**

The test plans reference the `BaselineTests` native target by its `project.pbxproj` identifier. It is expected to be `BC3C8FF69C3D1B0398FBF023`.

Run: `grep -B1 'isa = PBXNativeTarget' Baseline.xcodeproj/project.pbxproj | grep 'BaselineTests'`
Expected: a line of the form `<UUID> /* BaselineTests */ = {`. Use that exact `<UUID>` wherever the test-plan JSON below shows `BC3C8FF69C3D1B0398FBF023`. If it matches, proceed unchanged.

- [ ] **Step 2: Create `Baseline.xctestplan` (all tests — default plan)**

```json
{
  "configurations" : [
    {
      "id" : "9F1E2D3C-0000-0000-0000-000000000001",
      "name" : "Default",
      "options" : { }
    }
  ],
  "defaultOptions" : { },
  "testTargets" : [
    {
      "target" : {
        "containerPath" : "container:Baseline.xcodeproj",
        "identifier" : "BC3C8FF69C3D1B0398FBF023",
        "name" : "BaselineTests"
      }
    }
  ],
  "version" : 1
}
```

- [ ] **Step 3: Create `Baseline-CI.xctestplan` (logic tests — snapshot classes skipped)**

```json
{
  "configurations" : [
    {
      "id" : "9F1E2D3C-0000-0000-0000-000000000002",
      "name" : "CI",
      "options" : { }
    }
  ],
  "defaultOptions" : { },
  "testTargets" : [
    {
      "skippedTests" : [
        "BodyViewSnapshotTests",
        "HistoryViewSnapshotTests",
        "NowViewSnapshotTests",
        "ScanEntrySnapshotTests",
        "SettingsViewSnapshotTests",
        "TrendsViewSnapshotTests",
        "WeighInSheetSnapshotTests"
      ],
      "target" : {
        "containerPath" : "container:Baseline.xcodeproj",
        "identifier" : "BC3C8FF69C3D1B0398FBF023",
        "name" : "BaselineTests"
      }
    }
  ],
  "version" : 1
}
```

- [ ] **Step 4: Create `Baseline-Snapshots.xctestplan` (snapshot tests only)**

```json
{
  "configurations" : [
    {
      "id" : "9F1E2D3C-0000-0000-0000-000000000003",
      "name" : "Snapshots",
      "options" : { }
    }
  ],
  "defaultOptions" : { },
  "testTargets" : [
    {
      "selectedTests" : [
        "BodyViewSnapshotTests",
        "HistoryViewSnapshotTests",
        "NowViewSnapshotTests",
        "ScanEntrySnapshotTests",
        "SettingsViewSnapshotTests",
        "TrendsViewSnapshotTests",
        "WeighInSheetSnapshotTests"
      ],
      "target" : {
        "containerPath" : "container:Baseline.xcodeproj",
        "identifier" : "BC3C8FF69C3D1B0398FBF023",
        "name" : "BaselineTests"
      }
    }
  ],
  "version" : 1
}
```

- [ ] **Step 5: Wire the test plans into the scheme**

In `project.yml`, find the `Baseline` scheme's `test` section. It currently reads:

```yaml
    test:
      config: Debug
      targets:
        - BaselineTests
```

Replace it with:

```yaml
    test:
      config: Debug
      testPlans:
        - path: Baseline.xctestplan
          defaultPlan: true
        - path: Baseline-CI.xctestplan
        - path: Baseline-Snapshots.xctestplan
```

- [ ] **Step 6: Regenerate the Xcode project**

Run: `make generate`
Expected: `xcodegen` reports `Created project at .../Baseline.xcodeproj` with no errors. If xcodegen errors on the `testPlans` key, confirm the indentation matches the surrounding YAML and retry.

- [ ] **Step 7: Verify the logic test plan excludes snapshots**

Run: `make test`
Expected: `xcodebuild` runs the `Baseline-CI` plan. The run executes the logic tests (Models, ViewModels, OCR, Health, Sync, Utilities) and ends with `** TEST SUCCEEDED **`. None of the seven `*SnapshotTests` classes appear in the output.

- [ ] **Step 8: Verify the full plan includes snapshots**

Run: `make test-all`
Expected: the run additionally executes the seven `*SnapshotTests` classes and ends with `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add Baseline.xctestplan Baseline-CI.xctestplan Baseline-Snapshots.xctestplan project.yml Baseline.xcodeproj
git commit -m "test: add test plans splitting logic tests from snapshot tests"
```

---

## Task 6: Native pre-commit hook

**Files:**
- Create: `hooks/pre-commit`

- [ ] **Step 1: Create the hook script**

Create `hooks/pre-commit`:

```bash
#!/usr/bin/env bash
# Baseline pre-commit hook. Installed via `make setup` (sets core.hooksPath=hooks).
# Blocks the commit on: merge-conflict markers, files larger than 1 MB, and
# SwiftLint *error*-severity violations. Warnings print but do not block — see
# the SwiftLint ratchet in
# docs/superpowers/specs/2026-05-16-phase-1-testing-ci-foundation-design.md
set -euo pipefail

fail() { echo "pre-commit: $1" >&2; exit 1; }

staged=$(git diff --cached --name-only --diff-filter=ACM)
[ -z "$staged" ] && exit 0

# 1. Merge-conflict markers.
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if grep -nE '^(<{7}|={7}|>{7})( |$)' "$f" >/dev/null 2>&1; then
    fail "merge-conflict marker found in $f"
  fi
done <<< "$staged"

# 2. Large files (>1 MB).
while IFS= read -r f; do
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" | tr -d ' ')
  if [ "$size" -gt 1048576 ]; then
    fail "$f is $((size / 1024)) KB (>1 MB). Add it to .gitignore or commit it deliberately."
  fi
done <<< "$staged"

# 3. SwiftLint on staged Swift files. Blocks only on error-severity violations.
swift_files=$(echo "$staged" | grep '\.swift$' || true)
if [ -n "$swift_files" ]; then
  if ! command -v swiftlint >/dev/null 2>&1; then
    echo "pre-commit: swiftlint not installed — skipping lint. Run 'make setup'." >&2
  elif ! echo "$swift_files" | tr '\n' '\0' | xargs -0 swiftlint lint --quiet; then
    fail "SwiftLint reported error-severity violations. Fix them or run 'make format'."
  fi
fi

echo "pre-commit: checks passed."
```

- [ ] **Step 2: Make the hook executable**

Run: `chmod +x hooks/pre-commit`
Expected: no output.

- [ ] **Step 3: Activate the hooks directory**

Run: `git config core.hooksPath hooks`
Expected: no output. (This is also done by `make setup`; running it here activates the hook for the verification steps below.)

- [ ] **Step 4: Verify the hook blocks a merge-conflict marker**

```bash
printf '<<<<<<< HEAD\nx\n=======\ny\n>>>>>>> branch\n' > hook-test.txt
git add hook-test.txt
git commit -m "should be blocked" || echo "BLOCKED AS EXPECTED"
```
Expected: the commit is rejected and `BLOCKED AS EXPECTED` prints, with a `pre-commit: merge-conflict marker found in hook-test.txt` message.

- [ ] **Step 5: Clean up the test file**

```bash
git restore --staged hook-test.txt
rm hook-test.txt
```
Expected: no output; `git status` shows no `hook-test.txt`.

- [ ] **Step 6: Verify a clean commit passes**

```bash
git add hooks/pre-commit
git commit -m "build: add native git pre-commit hook (swiftlint + hygiene checks)"
```
Expected: the commit succeeds and `pre-commit: checks passed.` prints.

---

## Task 7: GitHub Actions CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create the workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    name: Build & Test
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode 26
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '26.4'

      - name: Cache SwiftPM packages
        uses: actions/cache@v4
        with:
          path: .build/DerivedData/SourcePackages
          key: spm-${{ runner.os }}-${{ hashFiles('Baseline.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved') }}
          restore-keys: |
            spm-${{ runner.os }}-

      - name: Install tooling
        run: brew install swiftlint xcbeautify

      - name: Lint (non-blocking)
        run: make lint || true

      - name: Build & test (logic)
        run: make test
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow running lint + logic tests"
```

- [ ] **Step 3: Push the branch and open the PR**

```bash
git push -u origin feat/phase-1-testing-ci
gh pr create --base main --head feat/phase-1-testing-ci \
  --title "Phase 1: testing/CI/lint foundation" \
  --body "Implements docs/superpowers/specs/2026-05-16-phase-1-testing-ci-foundation-design.md — Brewfile, Makefile, SwiftLint + pre-commit hook, test plans, and GitHub Actions CI."
```
Expected: the PR is created and its URL prints.

- [ ] **Step 4: Verify CI runs and passes**

Run: `gh run watch` (or `gh run list --branch feat/phase-1-testing-ci`)
Expected: the `CI` workflow runs the `Build & Test` job on a macOS runner. The job selects Xcode 26.x, installs tooling, runs lint (non-blocking), and runs `make test` (logic tests) to a passing finish. The run is green.

If the job fails on the runner image or Xcode version: confirm GitHub's current macOS runner label exposes Xcode 26.x. Adjust `runs-on:` (for example `macos-26`) and/or the `setup-xcode` `xcode-version:` to a value the runner provides, commit, and push again.

- [ ] **Step 5: Enable the branch-protection merge gate (optional, recommended)**

Once the CI run is green, require it before merges to `main`. Do this in the GitHub UI (the REST API for branch protection requires several fields to be explicitly `null`, which is error-prone from the command line):

1. Repo → **Settings** → **Branches** → **Add branch ruleset** (or "Add rule") for `main`.
2. Enable **Require status checks to pass before merging**.
3. Add **Build & Test** as a required status check (search for it — it appears after the first CI run completes).
4. Save.

This is reversible. If you prefer to leave `main` unprotected for now, skip it — CI still runs and reports its result on every PR regardless.

---

## Done

The PR opened in Task 7 contains all of Phase 1. Review it, confirm CI is green, and merge. After merge:

- The strict-ratchet follow-up (flip SwiftLint to `--strict`, make lint a hard gate, add `BaselineTests` rule relaxations) is deferred — see the spec's "Follow-ups" section.
- Phase 2 (UI test target, launch-arg test mode, docs discipline) gets its own brainstorm → spec → plan cycle.
