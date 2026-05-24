# SwiftLint Strict-Ratchet Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drive SwiftLint to zero warnings, then flip the config + pre-commit hook + CI to `--strict` hard gates (closes #75).

**Architecture:** Three levers reach zero warnings without large refactors: (1) tune the root config — extend `identifier_name.excluded`, remove the misplaced `legacy_random` opt-in, and raise length/complexity thresholds to just above current ceilings (tracked for ratchet-down by a new follow-up refactor issue); (2) a nested `BaselineTests/.swiftlint.yml` relaxing test-only noise (`force_try`, `force_cast`, length, `multiline_*`, `no_print`, `identifier_name`); (3) real but mechanical fixes to genuine production style hits (convert `#if DEBUG` `print()` to `Logger`, wrap long lines, fix `for_where`/`pattern_matching_keywords`/`nesting`/`multiline_*`). Then make all three gates strict.

**Tech Stack:** SwiftLint 0.63.2, Swift 6 / Xcode 26.3, bash pre-commit hook (`core.hooksPath=hooks`), GitHub Actions (`.github/workflows/ci.yml`), Makefile targets.

**Decisions locked (from #75 triage):**
- Tests: relax via nested config (per-path relaxations).
- `no_print`: convert production `#if DEBUG` prints to `Logger`; allow `print` in tests.
- `identifier_name`: extend `excluded` list (config-only).
- Length/complexity (all 8 oversized files incl. TrendsView): **raise thresholds + file a follow-up refactor issue.** No refactors in this pass.
- `legacy_random`: remove from `opt_in_rules` (it is a default rule).
- `operator_usage_whitespace` / InBodyDocumentParser: **moot** — 0 current violations (autocorrect already applied). No exclusion needed.

**Current ceilings (thresholds must sit just above these):**
- `file_length`: 1648 (TrendsView)
- `type_body_length`: 1305 (TrendsView)
- `function_body_length`: 187 (TrendsView)
- `cyclomatic_complexity`: 36 (InBodyParseResult)
- `function_parameter_count`: 8 (TrendsView)
- `large_tuple`: 3 members

**Verification baseline:** `swiftlint lint --quiet 2>&1 | grep -c warning` → **626** at start. Target → **0**, then `swiftlint lint --strict` exits 0.

---

### Task 1: Tune root config — opt-in cleanup, identifier exclusions, threshold raises

**Files:**
- Modify: `.swiftlint.yml`

- [ ] **Step 1: Remove the misplaced `legacy_random` opt-in rule**

In `opt_in_rules`, delete the line `  - legacy_random` (it is a default rule, not opt-in — keeping it under `opt_in_rules` is a no-op at best and a config smell).

- [ ] **Step 2: Extend `identifier_name` exclusions for idiomatic single-char names**

Replace the `identifier_name` block with:

```yaml
identifier_name:
  min_length: 2
  # Idiomatic single-char names: color destructuring (r/g/b), geometry/closure
  # params, loop indices, math deltas, transient bindings. See #75.
  excluded: [id, db, x, y, z, r, g, b, i, j, k, v, dx, dy, to, vm, lhs, rhs]
  validates_start_with_lowercase: warning
```

- [ ] **Step 3: Raise length/complexity thresholds to just above current ceilings**

These inflated values are temporary — the follow-up refactor issue (Task 6) ratchets them back down as files shrink. Update the four blocks and add the two missing ones:

```yaml
# Length/complexity thresholds raised to clear the current codebase. These are
# INTENTIONALLY inflated above today's worst offenders so --strict passes; the
# refactor follow-up issue ratchets them back toward defaults. See #75.
line_length:
  warning: 120
  ignores_comments: true
  ignores_urls: true
file_length:
  warning: 1700        # current max 1648 (TrendsView.swift)
type_body_length:
  warning: 1350        # current max 1305 (TrendsView)
function_body_length:
  warning: 200         # current max 187 (TrendsView)
cyclomatic_complexity:
  warning: 40          # current max 36 (InBodyParseResult)
  error: 50
large_tuple:
  warning: 3           # blesses existing 3-member tuples
  error: 99
function_parameter_count:
  warning: 9           # current max 8 (TrendsView)
```

(Remove the now-superseded standalone `cyclomatic_complexity` and `large_tuple` blocks higher in the file so each rule is configured exactly once.)

- [ ] **Step 4: Verify the targeted rule categories now report zero**

Run: `swiftlint lint --quiet 2>&1 | grep -E '\((identifier_name|file_length|type_body_length|function_body_length|cyclomatic_complexity|large_tuple|function_parameter_count)\)' | wc -l`
Expected: `0` (down from 147+9+9+8+19+7+6 = 205). If any remain, the offender exceeds the chosen ceiling — bump that single threshold to just above the reported value and re-run.

- [ ] **Step 5: Commit**

```bash
git add .swiftlint.yml
git commit -m "chore(lint): tune root config — drop legacy_random, extend identifier exclusions, raise length/complexity thresholds (#75)"
```

---

### Task 2: Nested test-target config relaxing test-only noise

**Files:**
- Create: `BaselineTests/.swiftlint.yml`

- [ ] **Step 1: Write the nested config**

SwiftLint auto-detects nested `.swiftlint.yml` files and applies them to files in that subtree. This relaxes test-only noise while keeping production strict (note: all 140 `force_try` hits are in tests; production has zero).

```yaml
# Nested config for the test target. SwiftLint applies this to files under
# BaselineTests/. Tests legitimately use try!/as! against known-good fixtures,
# have long table-driven methods/large suites, wide argument lists, console
# print(), and single-char fixture vars. Relax those here; production stays
# strict under the root .swiftlint.yml. See #75.
parent_config: ../.swiftlint.yml

disabled_rules:
  - force_try
  - force_cast
  - line_length
  - multiline_arguments
  - multiline_parameters
  - file_length
  - type_body_length
  - function_body_length
  - large_tuple

custom_rules:
  no_print:
    name: "No print()"
    regex: 'a^'          # never matches — print() allowed in tests
    message: "n/a"
    severity: warning

identifier_name:
  min_length: 1          # allow single-char fixture vars in tests
```

- [ ] **Step 2: Verify the nested config is picked up and tests are clean**

Run: `swiftlint lint --quiet 2>&1 | grep BaselineTests | wc -l`
Expected: `0`. If SwiftLint prints a "Found multiple configurations" note that's fine; if test warnings remain, confirm `parent_config` resolved (run `swiftlint lint --quiet BaselineTests 2>&1 | head`) and that the rule names match the reported violations.

- [ ] **Step 3: Commit**

```bash
git add BaselineTests/.swiftlint.yml
git commit -m "chore(lint): nested test-target config relaxing test-only rules (#75)"
```

---

### Task 3: Convert production `#if DEBUG` print() to Logger

**Files:**
- Modify: `Baseline/OCR/InBodyDocumentParser.swift` (19 print sites, all inside `#if DEBUG`)
- Modify: `Baseline/Views/Body/DocumentScannerView.swift` (lines 39, 53)
- Reference: `Baseline/Utilities/Log.swift` (existing `Logger` helper, subsystem `com.cadre.baseline`)

- [ ] **Step 1: Read the Log helper to learn the exact call surface**

Run: `sed -n '1,90p' Baseline/Utilities/Log.swift`
Note the public API (category-based `Logger` accessor, e.g. `Log.ocr` / `Log(category:)`). Use that exact surface in the edits below — do not invent a new logger.

- [ ] **Step 2: Replace the debug dump in InBodyDocumentParser with Logger calls**

For each `print("...")` inside a `#if DEBUG` block, replace with the project logger at `.debug` level, preserving interpolation. Example for the convert-failure guard:

```swift
guard let cgImage = image.cgImage else {
    Log.ocr.debug("[InBodyDocumentParser] Failed to convert UIImage to CGImage")
    return result
}
```

For the multi-line results dump (the `=== DOCUMENT PARSER RESULTS ===` block), collapse the per-field `print` loop into a single composed `Logger.debug` message so it stays one structured log line:

```swift
#if DEBUG
let summary = fields.compactMap { key, val in val.map { "\(key)=\($0)" } }.joined(separator: ", ")
Log.ocr.debug("InBody parsed fields: \(summary, privacy: .public)")
if let date = result.scanDate { Log.ocr.debug("InBody scanDate: \(String(describing: date), privacy: .public)") }
#endif
```

(Match `Log.ocr` to whatever the actual category accessor is from Step 1; if no `ocr` category exists, use the closest existing one or `Log(category: "OCR")` per the helper's pattern.)

- [ ] **Step 3: Replace the two prints in DocumentScannerView**

Run `sed -n '30,58p' Baseline/Views/Body/DocumentScannerView.swift` to see context, then replace each `print(...)` with the matching `Log.<category>.debug(...)` call, keeping any `#if DEBUG` guards intact.

- [ ] **Step 4: Verify no_print is zero in production and the project still builds**

Run: `swiftlint lint --quiet 2>&1 | grep no_print | wc -l`
Expected: `0`.
Run: `make build`
Expected: build succeeds (xcbeautify output ends without error).

- [ ] **Step 5: Commit**

```bash
git add Baseline/OCR/InBodyDocumentParser.swift Baseline/Views/Body/DocumentScannerView.swift
git commit -m "chore(lint): replace debug print() with Logger in OCR + scanner (#75)"
```

---

### Task 4: Fix residual production style violations

**Files (each fixed in place; run `make build` once at the end):**
- `Baseline/Views/Body/ScanEntryFlow.swift` (line_length ×22)
- `Baseline/Views/Trends/TrendsView.swift` (line_length ×16, multiline_arguments ×20)
- `Baseline/Views/Settings/SettingsSubscreens.swift` (line_length ×10)
- `Baseline/Utilities/TestDataSeeder.swift` (multiline_arguments ×18)
- `Baseline/Views/Now/NowView.swift` (line_length ×4)
- `Baseline/Utilities/CSVImporter.swift` (line_length ×4, for_where ×1 @241, multiple_closures_with_trailing_closure ×1 @620)
- `Baseline/OCR/InBodyDocumentParser.swift` (line_length ×5, multiline_function_chains ×1 @906)
- `Baseline/Views/Body/ScanDetailView.swift` (line_length ×2)
- `Baseline/ViewModels/TrendsViewModel.swift` (line_length ×2)
- `Baseline/Utilities/CSVExporter.swift` (line_length ×2)
- `Baseline/Views/Now/WeighInSheet.swift` (multiline_arguments ×2)
- `Baseline/ViewModels/BodyViewModel.swift` (for_where ×1 @231)
- `Baseline/OCR/InBodyParseResult.swift` (pattern_matching_keywords ×2 @335, line_length ×1)
- `Baseline/Design/Components/MetricTile.swift` (nesting ×1 @21)
- `Baseline/Models/Goal.swift`, `Baseline/Utilities/BaselineTips.swift`, `Baseline/Views/History/HistoryView.swift`, `Baseline/Views/Body/LogMeasurementSheet.swift`, `Baseline/ViewModels/WeighInViewModel.swift`, `Baseline/ViewModels/ScanEntryViewModel.swift` (line_length ×1 each)

- [ ] **Step 1: Generate the authoritative production violation list**

Run: `swiftlint lint --quiet 2>&1 | grep -v BaselineTests`
This is the worklist. Work top to bottom. (Tests are already clean from Task 2; if any test lines appear here, Task 2 regressed — fix that first.)

- [ ] **Step 2: Fix `line_length` violations by wrapping**

For each `line_length` hit, open the file at the reported line and wrap to ≤120 cols using idiomatic SwiftUI/Swift breaks: one modifier per line, arguments one-per-line, or extract a local `let`. Do **not** disable the rule inline. Example pattern:

```swift
// before (141 cols)
.foregroundStyle(condition ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.5))
// after
.foregroundStyle(
    condition ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.5)
)
```

- [ ] **Step 3: Fix `multiline_arguments` (TrendsView, TestDataSeeder, WeighInSheet)**

Put either all arguments on the same line or exactly one per line — never mixed. Example:

```swift
// before (mixed)
Foo(a: 1, b: 2,
    c: 3)
// after
Foo(
    a: 1,
    b: 2,
    c: 3
)
```

- [ ] **Step 4: Fix the one-off rules**

- `for_where` (`BodyViewModel.swift:231`, `CSVImporter.swift:241`): fold a lone `if` inside a `for` into a `where` clause: `for x in xs where cond { ... }`.
- `pattern_matching_keywords` (`InBodyParseResult.swift:335`): move `let` out of the tuple — `case let (a, b)` instead of `case (let a, let b)`.
- `nesting` (`MetricTile.swift:21`): lift the type nested >1 level deep up to file scope (or one level), renaming if needed to avoid collision.
- `multiple_closures_with_trailing_closure` (`CSVImporter.swift:620`): pass all closures as explicit labeled arguments rather than trailing-closure syntax.
- `multiline_function_chains` (`InBodyDocumentParser.swift:906`): put the whole chain on one line, or one `.call` per line.

- [ ] **Step 5: Verify zero warnings remain across the whole project**

Run: `swiftlint lint --quiet 2>&1 | grep -c warning`
Expected: `0`.
Run: `swiftlint lint --strict`
Expected: exit 0, prints "Done linting! Found 0 violations".

- [ ] **Step 6: Verify the app still builds and logic tests pass**

Run: `make test`
Expected: build + logic tests succeed (no compile errors introduced by wraps/edits).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore(lint): clear residual production style violations (#75)"
```

---

### Task 5: Flip the gates to `--strict`

**Files:**
- Modify: `.swiftlint.yml` (header comment)
- Modify: `Makefile` (`lint` target)
- Modify: `hooks/pre-commit`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Update the `lint` Makefile target to strict**

Replace `Makefile:76-77`:

```makefile
lint:
	swiftlint lint --strict
```

- [ ] **Step 2: Make the pre-commit hook a hard gate**

In `hooks/pre-commit`, change the staged-file lint invocation to `--strict` so any violation (warning or error) blocks the commit, and update the failure message + the header comment that currently says "Blocks ... only on error-severity violations" / "Warnings print but do not block":

```bash
  elif ! echo "$swift_files" | tr '\n' '\0' | xargs -0 swiftlint lint --strict --quiet; then
    fail "SwiftLint reported violations (strict mode). Fix them or run 'make format'."
  fi
```

Update the top comment block to: "Blocks the commit on: merge-conflict markers, files larger than 1 MB, and ANY SwiftLint violation (strict mode)."

- [ ] **Step 3: Make CI a hard gate**

In `.github/workflows/ci.yml`, replace the lint step:

```yaml
      - name: Lint (strict)
        run: make lint
```

(Removes `|| true` and the "non-blocking" name so a violation fails the job.)

- [ ] **Step 4: Update the root config header comment**

In `.swiftlint.yml`, replace the opening comment block (which describes the lenient ratchet start and the softened severities) with a note that the strict ratchet has landed: strict mode is on, hook + CI are hard gates, and the inflated length/complexity thresholds are tracked for ratchet-down by the refactor follow-up issue. Confirm the `force_cast` / `force_try` `severity: warning` softeners can stay (they are still warnings, but under `--strict` they now block — which is the intent for production).

- [ ] **Step 5: Verify the strict gate fires end-to-end**

Run: `make lint`
Expected: exit 0 (codebase is clean).
Prove the gate blocks by temporarily introducing a violation and confirming non-zero exit:

```bash
printf '\nlet _UNUSED = try! String(contentsOfFile: "/nope")\n' >> Baseline/Utilities/DateFormatting.swift
make lint; echo "exit=$?"   # expect non-zero
git checkout Baseline/Utilities/DateFormatting.swift
make lint; echo "exit=$?"   # expect 0
```

- [ ] **Step 6: Commit**

```bash
git add .swiftlint.yml Makefile hooks/pre-commit .github/workflows/ci.yml
git commit -m "ci: flip SwiftLint to --strict hard gate in hook + CI + make lint (#75)"
```

---

### Task 6: File follow-up refactor issue and close #75

**Files:** none (GitHub only)

- [ ] **Step 1: Open the refactor follow-up issue**

```bash
gh issue create --label tech-debt \
  --title "Refactor oversized files to ratchet SwiftLint length/complexity thresholds back down" \
  --body "Issue #75 raised length/complexity thresholds to clear the strict gate without refactors. Ratchet them back toward defaults by decomposing the oversized files:

Files over 600-line file_length: TrendsView.swift (1648), SettingsSubscreens.swift (1207), CSVImporter.swift (1060), ScanEntryFlow.swift (1033), InBodyDocumentParser.swift (932), TrendsViewModel.swift (899), SettingsView.swift (676), ScanEntryViewModel.swift (660).
Oversized type bodies: TrendsView (1305), ScanEntryFlow (855), InBodyDocumentParser (667), TrendsViewModel (493), ScanEntryViewModel (482), CSVImporter (469), BodyView (458).
High cyclomatic complexity (max 36): InBodyParseResult, InBodyDocumentParser, TrendsViewModel.
Also: function_parameter_count up to 8 (TrendsView), large_tuple 3-member sites.

Current temporary thresholds in .swiftlint.yml: file_length 1700, type_body_length 1350, function_body_length 200, cyclomatic_complexity 40, function_parameter_count 9, large_tuple 3. Lower each as files are decomposed."
```

- [ ] **Step 2: Verify the full strict run one last time, then close #75**

```bash
swiftlint lint --strict && echo "STRICT CLEAN"
gh issue close 75 --comment "Strict ratchet landed: --strict is on in .swiftlint.yml usage, the pre-commit hook, and CI; all 626 warnings cleared (tests relaxed via nested config, prod prints → Logger, residual style fixed, length/complexity thresholds raised). Threshold ratchet-down tracked in the new refactor follow-up issue."
```

---

## Notes for the executor
- After **every** task, run `git status` and confirm the tree is clean (no orphaned modified files outside the scoped `git add`). Scoped adds can leave unstaged edits while build/test still pass on the dirty tree.
- The single source of truth for progress is `swiftlint lint --quiet 2>&1 | grep -c warning` trending 626 → 0, then `swiftlint lint --strict` exit 0.
- Do not introduce inline `// swiftlint:disable` to hit zero — that defeats the gate. The only sanctioned escape hatches are the threshold raises (Task 1) and the nested test config (Task 2).
