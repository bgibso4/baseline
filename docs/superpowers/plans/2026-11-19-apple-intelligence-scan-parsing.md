# Apple Intelligence Scan Parsing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When Apple Intelligence is available, the on-device model reads an InBody scan section by section and fills the existing review form; otherwise the app behaves exactly as on `main`.

**Architecture:** `ScanEntryViewModel` gets a page reader by injection (`ScanPageReading`). One conformer wraps today's parser untouched. The other, `InBodyIntelligenceReader`, prepares the image, locates sections from Vision-recognised headings, asks the system language model one small question per section crop, then range-checks and cross-checks the answers into an `InBodyParseResult`. Locating and asking sit behind narrow protocols so everything but the two system adapters is unit-tested with fakes.

**Tech Stack:** Swift, SwiftUI/MVVM, Vision `RecognizeDocumentsRequest`, FoundationModels (`SystemLanguageModel`, `LanguageModelSession`, `@Generable`, `Attachment`), XCTest, XcodeGen, SwiftLint. iOS deployment target 27.0.

**Spec:** `docs/superpowers/specs/2026-11-19-apple-intelligence-scan-parsing-design.md`

## Global Constraints

- On-device only: use `SystemLanguageModel.default`. Never `PrivateCloudComputeLanguageModel`, never a network call. Do not edit the privacy policy, `PrivacyInfo.xcprivacy` or `docs/APP_REVIEW_NOTES.md`.
- Do not edit `Baseline/OCR/InBodyDocumentParser.swift` or `Baseline/OCR/CrossFieldValidator.swift`. With the model unavailable, results must be identical to `main`.
- No SwiftData/CloudKit schema change. No new UI controls; no UI mocks.
- Read `CLAUDE.md` first. One primary type per file; no `print()` in app code (`Log.scan`); errors logged with `Log.scan.error`; never widen a lint threshold; never `--no-verify`; never push to `main`.
- Work on branch `feat/49-apple-intelligence-scan-parsing`, in the main checkout (no worktree).
- **Commit steps run only once Ben has said commits are OK for this branch.** Stage explicit paths. Never stage `.serena/project.yml`. Push or open a PR only when Ben asks.
- After adding, moving or removing files run `make generate`.
- Simulator: `iPhone 17` (id `4A925923-95EB-4910-8E96-ED14823A65EB`). Never boot or use `FC iPhone 17`. Never erase simulators. One `xcodebuild test` at a time; kill only processes you started.
- Known local failure, also on `main`: `SetGoalFlowUITests`. `make test-snapshots` fails locally and is not a signal.
- Test command used below (call it **RUN**):
  `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,id=4A925923-95EB-4910-8E96-ED14823A65EB' -derivedDataPath .build/DerivedData -only-testing:BaselineTests/<Class>`
- Field keys everywhere are the existing `InBodyParseResult.allFieldKeys` strings (`weightKg`, `bodyFatPct`, …). Sheet values are stored raw (lbs), as today.

## Review Focus

1. Model available but without the `.vision` capability → parser reader is chosen (test in Task 9).
2. The model answers `0.0` for a value it cannot read (seen in the spike) → treated as blank even where `0` is inside the sane range (test in Task 4).
3. Extended-range camera image → prepared image is 8-bit sRGB; a failed conversion falls back to the parser instead of sending nothing to the model (tests in Tasks 5 and 6).
4. A page that is not an InBody sheet, or is rotated → fewer than two headings → parser fallback, no crash (test in Task 6).
5. Predicted section rectangle falls partly or wholly off the page → clamped, or dropped if empty (test in Task 3).

---

### Task 0: Device timing gate

Uses the throwaway spike already in the working tree (`BaselineTests/OCR/FoundationModelsVisionSpikeTests.swift`). No product code.

- [ ] **Step 1:** In the spike's `sheets` list keep only `clean`, `marked`, `review-sample` (the `scan*` entries read Mac paths a phone cannot see).
- [ ] **Step 2:** Ask Ben to connect and unlock their iPhone, then run:
  `TEST_RUNNER_RUN_FM_SPIKE=1 xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS,name=<Ben's device name>' -derivedDataPath .build/DerivedData -only-testing:BaselineTests/FoundationModelsVisionSpikeTests`
  If signing or device access blocks the run, stop and tell Ben exactly what failed.
- [ ] **Step 3:** Record the three `model <N>s` lines and the right/wrong totals in the spec under "Speed". Decision: median ≤ 10 s → continue with this plan. Median > 10 s → stop; bring Ben the numbers and the two options in the spec.
- [ ] **Step 4:** Copy the spike file to the session scratchpad for reference, delete it from the repo, `make generate`, confirm `git status --short` shows no spike file and no leftover project-file diff beyond what `make generate` produces on a clean tree.

### Task 1: Reader seam, parser path unchanged

**Files:**
- Create: `Baseline/OCR/ScanPageReading.swift`, `Baseline/OCR/ParserPageReader.swift`
- Modify: `Baseline/ViewModels/ScanEntryViewModel.swift` (init at ~l.117, `processScan` at ~l.255)
- Test: `BaselineTests/ViewModels/ScanEntryViewModelTests.swift`

**Interfaces — Produces:**
```swift
protocol ScanPageReading: Sendable {
    /// Reads one page. Confidence in the result reflects how far each value can be trusted.
    func read(page: UIImage) async -> InBodyParseResult
    /// Optional warm-up before the first read. Default: no-op.
    func prepare()
}
struct ParserPageReader: ScanPageReading   // read = InBodyDocumentParser.parse(image:)
// ScanEntryViewModel
init(modelContext: ModelContext, makePageReader: @escaping () -> any ScanPageReading = { ParserPageReader() })
func processPages(count: Int, image: (Int) -> UIImage) async   // processScan(_:) calls this
```
`processPages` asks `makePageReader()` once per call, then keeps today's loop (downscale to 2048, read, append to `allPageResults`), vote and populate logic exactly as now.

- [ ] **Step 1: Failing tests** in `ScanEntryViewModelTests`, with a `FakePageReader` returning a canned result:
  - `testProcessPagesUsesInjectedReader`: reader returns `weightKg = 199.4` with confidence 0.9 → `vm.fields["weightKg"] == "199.4"`, `vm.currentStep == .review`, reader called once for `count: 1`.
  - `testLoneParserResultStaysFlagged`: same result → `vm.lowConfidenceFields.contains("weightKg")` (today's 0.4 cap still applies).
- [ ] **Step 2:** RUN `ScanEntryViewModelTests` → fails to compile (`processPages` missing).
- [ ] **Step 3:** Implement the protocol (with `extension ScanPageReading { func prepare() {} }`), `ParserPageReader`, and the view-model change.
- [ ] **Step 4:** RUN `ScanEntryViewModelTests`, `InBodyDocumentParserFixtureTests`, `InBodyDocumentParserTests`, `ConsensusVoteTests` → pass.
- [ ] **Step 5:** `make generate`; commit `refactor: inject scan page reader into ScanEntryViewModel (#49)`.

### Task 2: Fixtures and ground truth

**Files:**
- Create: `BaselineTests/Fixtures/Scans/flat-0319.jpg`, `flat-0414.jpg`, `flat-0515-0723.jpg`, `flat-0515-0726.jpg`, `flat-0804.jpg`, `flat-0922.jpg`
- Create: `BaselineTests/OCR/ScanFixtureTruth.swift`
- Test: `BaselineTests/OCR/ScanFixtureTruthTests.swift`

Sources in `/Users/ben/Downloads/InBody Scans/`: `Inbody Scan - 03-19-2026.pdf`, `InBody Scan - 04-14-2026.pdf`, `InBody Scan - 6.pdf` (05-15 07:23), `InBody Scan - 05-15-2026.pdf` (07:26), `InBody Scan - 08-04-2026.pdf`, `InBody Scan - 09-22-2026.pdf`. Render with `sips -s format jpeg -Z 2400`, lowering `formatOptions` until each file is under 1 MB (the pre-commit hook rejects larger files).

**Interfaces — Produces:**
```swift
struct ScanFixtureTruth {
    let name: String                 // resource name without extension
    let values: [String: Double]     // all 34 keys below
    let testDate: DateComponents?    // year/month/day; nil where the sheet's date is unreadable (flat-0804)
    let isMisprinted: Bool           // true for flat-0804 only
    static let all: [ScanFixtureTruth]   // clean, marked, review-sample + the six flat scans
    static func image(named: String) throws -> UIImage   // loads from the test bundle, orientation baked in
}
```
The 34 keys: the 7 core, `intracellularWaterL`, `extracellularWaterL`, `dryLeanMassKg`, `leanBodyMassKg`, the 10 segmental lean, `ecwTbwRatio`, the 10 segmental fat, `visceralFatLevel`, `skeletalMuscleIndex`.

Values (order: weight, SMM, fat mass, PBF, TBW, BMI, BMR, ICW, ECW, DLM, LBM; lean lbs/% for RA, LA, trunk, RL, LL; ECW/TBW; fat lbs/% for RA, LA, trunk, RL, LL; visceral; SMI):
- 03-19 (`marked`, `flat-0319`): 197.2, 105.8, 14.2, 7.2, 134.0, 26.0, 2162, 84.7, 49.4, 48.9, 183.0; 11.49/138.0, 11.38/136.6, 80.9/121.9, 27.67/119.5, 28.02/121.1; 0.369; 0.2/14.4, 0.2/14.4, 6.8/65.7, 2.2/50.4, 2.2/50.9; 1; 10.4
- 04-14 (`clean`, `flat-0414`): 199.4, 108.2, 12.0, 6.1, 137.1, 26.3, 2205, 86.4, 50.7, 50.3, 187.4; 11.51/137.8, 11.40/136.4, 80.9/121.6, 28.55/122.9, 28.59/123.2; 0.369; 0.2/13.6, 0.2/13.6, 5.7/53.9, 1.8/43.3, 1.8/43.0; 1; 10.6
- 05-15 07:23: 196.8, 108.5, 9.6, 4.9, 137.4, 26.0, 2205, 86.4, 50.9, 49.8, 187.2; 11.79/141.9, 11.57/139.0, 82.1/123.8, 28.55/123.5, 28.66/123.9; 0.370; 0.2/13.5, 0.2/13.5, 4.0/36.9, 1.5/35.6, 1.5/35.6; 1; 10.6
- 05-15 07:26: 196.8, 108.0, 10.1, 5.1, 136.9, 26.0, 2200, 86.2, 50.7, 49.8, 186.7; 11.73/141.1, 11.49/138.1, 81.7/123.3, 28.62/123.7, 28.75/124.4; 0.370; 0.2/13.5, 0.2/13.5, 4.2/40.0, 1.5/37.6, 1.5/37.7; 1; 10.6
- 08-04: 199.1, 108.9, 10.8, 5.5, 137.8, 26.3, 2214, 86.9, 50.9, 50.5, 188.3; 11.55/138.3, 11.64/139.5, 81.7/122.9, 28.59/123.3, 29.10/125.4; 0.369; 0.2/13.5, 0.2/13.5, 4.9/46.0, 1.8/39.3, 1.8/40.2; 1; 10.7
- 09-22: 200.6, 109.4, 11.0, 5.5, 138.9, 26.5, 2227, 87.3, 51.6, 50.7, 189.6; 11.79/141.1, 11.79/141.1, 82.7/124.1, 28.84/124.0, 29.04/124.8; 0.372; 0.2/13.6, 0.2/13.6, 4.9/46.8, 1.8/39.8, 1.8/40.0; 1; 10.8

These were read off the images by Claude. Before relying on them: open each new JPEG at full size and re-check the two-decimal segmental lean values; list for Ben any digit you are not sure of.

- [ ] **Step 1:** Render the six JPEGs; confirm each is under 1 MB.
- [ ] **Step 2:** Open `review-sample.jpg`, transcribe all 34 values and its test date, and show Ben the table to confirm (its core seven are already in `InBodyDocumentParserFixtureTests`).
- [ ] **Step 3: Failing test** `ScanFixtureTruthTests.testEveryFixtureLoadsAndIsComplete`: for each entry in `ScanFixtureTruth.all`, `image(named:)` loads, and `Set(values.keys) == the 34 keys`; `all.count == 9`.
- [ ] **Step 4:** RUN → fails; write `ScanFixtureTruth.swift`; `make generate`; RUN → passes.
- [ ] **Step 5:** Commit `test: add flat InBody scan fixtures and full ground truth (#49)`.

### Task 3: Sections and layout (pure)

**Files:**
- Create: `Baseline/OCR/Intelligence/SheetSection.swift`, `Baseline/OCR/Intelligence/SectionLayout.swift`
- Test: `BaselineTests/OCR/Intelligence/SectionLayoutTests.swift`

**Interfaces — Produces:**
```swift
enum SheetHeading: CaseIterable {   // printed headings used as anchors
    case bodyComposition, muscleFat, obesity, segmentalLean, ecwTbw, history   // left column
    case segmentalFat, basalMetabolicRate, visceralFat, smi, resultsInterpretation   // right column
    var isRightColumn: Bool
    var referenceY: Double          // position on the reference sheet, below
    func matches(_ lowercasedText: String) -> Bool
}
enum SheetSection: CaseIterable {
    case header, bodyComposition, muscleFat, obesity, segmentalLean, ecwTbw,
         segmentalFat, basalMetabolicRate, visceralFat, smi
}
enum SectionLayout {
    /// `found`: heading → distance of its centre from the top of the page, 0...1.
    /// Returns nil when fewer than two headings were found.
    /// Rects are normalised, top-left origin, clamped to the unit square; empty rects are omitted.
    static func rects(found: [SheetHeading: Double]) -> [SheetSection: CGRect]?
}
```
Rules, from the spike:
- Reference Y (same arbitrary unit for all): bodyComposition 320, muscleFat 610, obesity 872, segmentalLean 1055, ecwTbw 1457, history 1610, segmentalFat 515, basalMetabolicRate 740, visceralFat 805, smi 898, resultsInterpretation 962.
- Least-squares fit `observed = slope × reference + offset` over the found headings; a heading's position is its observed value if found, else predicted.
- A section spans from its heading + 0.008 to the next heading − 0.008. Pairs: bodyComposition→muscleFat, muscleFat→obesity, obesity→segmentalLean, segmentalLean→ecwTbw, ecwTbw→history (bottom extended by 0.03: misprinted sheets print the value low), segmentalFat→basalMetabolicRate, basalMetabolicRate→visceralFat, visceralFat→smi, smi→resultsInterpretation. `header` is the band from bodyComposition − 0.075 to bodyComposition − 0.008, full width.
- X range: left-column sections 0.0…0.66, right-column 0.60…1.0.
- Heading text matches (lowercased, trimmed, prefix unless noted): "body composition analysis", "muscle-fat analysis" or "muscle- fat analysis", "obesity analysis" or "obesity anaiysis", "segmental lean", "ecw/tbw analysis", "body composition history", "segmental fat analysis", "basal metabolic rate", "visceral fat level", "smi" (exact), "results interpretation".

- [ ] **Step 1: Failing tests** in `SectionLayoutTests`:
  - `testAllHeadingsFoundGivesTenSections`: `found` = every heading at `referenceY / 2000` → 10 rects; `rects[.obesity]!.minY ≈ 0.444`, `maxY ≈ 0.5195` (accuracy 0.001); `rects[.basalMetabolicRate]!.minX == 0.60`.
  - `testMissingHeadingIsPredicted`: same input without `.ecwTbw` → `rects[.segmentalLean]!.maxY ≈ 0.7205`.
  - `testScaledAndShiftedSheet`: positions `0.1 + 0.8 × referenceY / 2000` with `.obesity` removed → `rects[.muscleFat]!.maxY ≈ 0.1 + 0.8 × 0.436 − 0.008`.
  - `testFewerThanTwoHeadingsIsNil`: one heading → nil; empty → nil.
  - `testRectsAreClampedAndEmptyOnesDropped`: positions `0.9 + referenceY / 2000` → every returned rect lies inside the unit square and has height > 0; sections wholly below the page are absent.
  - `testHeadingMatching`: "Obesity Anaiysis" matches `.obesity`; "SMI" matches `.smi`; "smi skeletal muscle index(smi) is calculated" does not.
- [ ] **Step 2:** RUN → fails. **Step 3:** Implement. **Step 4:** RUN → passes. `make generate`.
- [ ] **Step 5:** Commit `feat: InBody sheet section layout (#49)`.

### Task 4: Readout validation (pure)

**Files:**
- Modify: `Baseline/OCR/InBodyParseResult.swift` (add two members; touch nothing else)
- Create: `Baseline/OCR/Intelligence/SectionReadout.swift`, `Baseline/OCR/Intelligence/ReadoutValidator.swift`
- Test: `BaselineTests/OCR/Intelligence/ReadoutValidatorTests.swift`, `BaselineTests/OCR/ConsensusVoteTests.swift`

**Interfaces — Produces:**
```swift
// InBodyParseResult
var isSelfValidated = false   // confidence already reflects validation; a lone result is not capped
static func saneRange(forKey key: String) -> ClosedRange<Double>?   // maps each field key to its SaneRange constant

struct SectionReadout: Equatable {
    var values: [String: Double] = [:]     // field key → value read
    var repeated: [String: Double] = [:]   // second printed copy (weightKg, bodyFatMassKg from the bar chart)
    var testDate: DateComponents?
}
enum ReadoutValidator {
    static let trusted: Float = 0.9
    static let flagged: Float = 0.3
    static func assemble(_ readouts: [SheetSection: SectionReadout], now: Date) -> InBodyParseResult
}
```
`consensusVote`'s single-result branch returns `results[0]` unchanged when `results[0].isSelfValidated`; otherwise exactly today's behaviour. `saneRange(forKey:)` uses the existing constants: arms `segLeanArmLbs`, legs `segLeanLegLbs`, trunk `segLeanTrunkLbs`, every `*LeanPct` `segLeanPct`, every `*FatKg` `segFatLbs`, every `*FatPct` `segFatPct`; `inBodyScore` → nil.

`assemble` rules: a value ≤ 0 or outside `saneRange(forKey:)` is dropped. A kept value gets confidence `trusted`. For each key in `repeated`: if both copies survive and differ by more than 0.05, that field's confidence becomes `flagged`; if only the repeated copy survives, use it with `flagged`. `testDate` becomes `scanDate` only if it forms a valid date that is not after `now` and not more than 5 years before it. The result has `isSelfValidated = true`.

- [ ] **Step 1: Failing tests**
  - `testInRangeValueIsTrusted`: `weightKg 199.4` → value kept, confidence 0.9, `isSelfValidated`.
  - `testOutOfRangeValueIsDropped`: `leftArmLeanKg 139.5` → nil, no confidence entry.
  - `testZeroIsDroppedEvenWhenInRange`: `bodyFatMassKg 0.0` → nil.
  - `testRepeatedMismatchFlags`: values `weightKg 199.4`, repeated `weightKg 197.2` → kept 199.4, confidence 0.3.
  - `testRepeatedAgreementIsTrusted`: both 199.4 → 0.9.
  - `testRepeatedFillsMissing`: no table weight, repeated 199.4 → 199.4 at 0.3.
  - `testDateWindow` with `now` = 2026-11-19: 2026-04-14 accepted; 2024-02-20 accepted; 2020-01-01 → nil; 2027-01-01 → nil; month 13 → nil.
  - `testSaneRangeCoversEveryFieldExceptScore`: every key in `allFieldKeys` except `inBodyScore` has a range.
  - In `ConsensusVoteTests`: `testLoneSelfValidatedResultKeepsConfidence` (0.9 stays 0.9) and `testLoneParserResultStillCapped` (0.9 → 0.4).
- [ ] **Step 2:** RUN `ReadoutValidatorTests` and `ConsensusVoteTests` → fail. **Step 3:** Implement. **Step 4:** RUN both plus `InBodyDocumentParserTests` → pass. `make generate`.
- [ ] **Step 5:** Commit `feat: validate model readouts into a parse result (#49)`.

### Task 5: Image preparation

**Files:** Create `Baseline/OCR/Intelligence/ScanImagePreparer.swift`; Test `BaselineTests/OCR/Intelligence/ScanImagePreparerTests.swift`

**Interfaces — Produces:** `enum ScanImagePreparer { static func standardRangeImage(from image: UIImage) -> CGImage? }` — redraws with `UIGraphicsImageRendererFormat` (`scale = 1`, `preferredRange = .standard`, `opaque = true`), baking in orientation.

- [ ] **Step 1: Failing tests:** `testCleanFixtureBecomesEightBitSRGB` (`bitsPerComponent == 8`, colour space name `CGColorSpace.sRGB`, pixel size equals the oriented size of `clean.jpg`); `testOrientationIsBakedIn` (a 100×200 image with orientation `.right` → width 200, height 100).
- [ ] **Step 2–4:** RUN fails → implement → RUN passes. `make generate`.
- [ ] **Step 5:** Commit `feat: prepare scan images for the on-device model (#49)`.

### Task 6: The intelligence reader (orchestration, with fakes)

**Files:**
- Create: `Baseline/OCR/Intelligence/SectionLocating.swift`, `Baseline/OCR/Intelligence/SectionReading.swift`, `Baseline/OCR/Intelligence/InBodyIntelligenceReader.swift`
- Test: `BaselineTests/OCR/Intelligence/InBodyIntelligenceReaderTests.swift`

**Interfaces — Consumes:** `ScanPageReading`, `SheetSection`, `SectionReadout`, `ReadoutValidator.assemble`, `ScanImagePreparer`.
**Produces:**
```swift
protocol SectionLocating: Sendable {
    func sectionRects(in image: CGImage) async -> [SheetSection: CGRect]?   // normalised, top-left origin
}
enum SectionReadingError: Error { case modelUnavailable }
protocol SectionReading: Sendable {
    func read(_ section: SheetSection, crop: CGImage) async throws -> SectionReadout
    func prepare()
}
struct InBodyIntelligenceReader: ScanPageReading {
    init(locator: any SectionLocating, sections: any SectionReading, fallback: any ScanPageReading,
         now: @escaping @Sendable () -> Date = Date.init)
}
```
`read(page:)`: prepare the image; locate; crop each rect; read sections in `SheetSection.allCases` order with the core sections first (bodyComposition, muscleFat, obesity, basalMetabolicRate, then the rest); assemble. Falls back to `fallback.read(page:)` when image preparation fails, when the locator returns nil, or when any section throws `SectionReadingError.modelUnavailable`. Any other section error: `Log.scan.error`, that section contributes nothing, the rest stand. Logs which path produced the result with `Log.scan.info`. `prepare()` forwards to `sections.prepare()`.

- [ ] **Step 1: Failing tests** (fake locator, fake section reader, fake fallback; use `clean.jpg` as the page):
  - `testAssemblesValuesFromSections`: fakes return weight 199.4 from `.bodyComposition` and PBF 6.1 from `.obesity` → result has both at confidence 0.9, `isSelfValidated`, fallback not called.
  - `testCoreSectionsAreReadFirst`: recorded call order starts bodyComposition, muscleFat, obesity, basalMetabolicRate.
  - `testOneSectionFailingLeavesOthers`: `.obesity` throws a generic error → `bodyFatPct == nil`, `weightKg == 199.4`, fallback not called.
  - `testModelUnavailableFallsBack`: `.muscleFat` throws `.modelUnavailable` → returns the fallback's result; `isSelfValidated == false`.
  - `testUnlocatablePageFallsBack`: locator returns nil → fallback's result.
  - `testCropsMatchRects`: locator returns `.obesity` = (0, 0.25, 0.5, 0.25) → the crop handed to the reader is half the image's width and a quarter of its height.
- [ ] **Step 2–4:** RUN fails → implement → RUN passes. `make generate`.
- [ ] **Step 5:** Commit `feat: InBodyIntelligenceReader orchestration (#49)`.

### Task 7: System adapters and the accuracy suite

**Files:**
- Create: `Baseline/OCR/Intelligence/VisionSectionLocator.swift`, `Baseline/OCR/Intelligence/SectionSchemas.swift`, `Baseline/OCR/Intelligence/FoundationModelsSectionReader.swift`
- Test: `BaselineTests/OCR/Intelligence/IntelligenceAccuracyTests.swift`

**Interfaces — Produces:** `struct VisionSectionLocator: SectionLocating`; `struct FoundationModelsSectionReader: SectionReading`.

`VisionSectionLocator`: `RecognizeDocumentsRequest` → for each paragraph, lowercased trimmed transcript and box centre; a heading counts only in its own column (right column = box origin x > 0.55); when a heading matches more than once keep the one nearest the top (the right column repeats headings in its explanations) → `SectionLayout.rects(found:)`. A thrown Vision error is logged with `Log.scan.error` and returns nil.

`FoundationModelsSectionReader`: one fresh `LanguageModelSession(instructions:)` per question; `respond(generating:options:)` with `GenerationOptions(samplingMode: .greedy)` and the prompt built as text followed by `Attachment(crop)`. Map `LanguageModelSession.GenerationError.assetsUnavailable` and a non-`.available` `SystemLanguageModel.default.availability` to `SectionReadingError.modelUnavailable`; rethrow everything else. `prepare()` creates a session and calls its `prewarm`.

Instructions (verbatim from the spike): "You read InBody 570 body composition result sheets. Report the printed result values for today's test exactly as printed. The bar charts have axis tick numbers (like 10.0, 15.0, 20.0) that are NOT results; the result is the number printed at the end of each bar. Ignore handwriting and pen marks. If a value cannot be read, leave it empty. Never guess."

Questions that scored without a wrong value in the spike — keep these shapes (`@Generable` structs of optional `Double`s with `@Guide` descriptions, in `SectionSchemas.swift`):
- bodyComposition, two questions on the same crop: the four numbers in the Values column top to bottom (ICW, ECW, DLM, fat mass); then the three totals left to right (TBW, LBM, weight).
- muscleFat: number at the end of the Weight, SMM and Body Fat Mass bars. Weight and fat mass go in `repeated`; SMM in `values`.
- obesity: number at the end of the BMI and PBF bars.
- ecwTbw: number at the end of the bar.
- segmentalFat: for each of five rows, the number in parentheses before "lbs" and the percentage after the bar.
- basalMetabolicRate (kcal), visceralFat (integer after "Level"), smi.
- header: test date as month, day, four-digit year.
- segmentalLean: start with one question for the whole section; Task 8 replaces it.

`IntelligenceAccuracyTests`: skipped unless `RUN_INTELLIGENCE_ACCURACY == "1"` (pass `TEST_RUNNER_RUN_INTELLIGENCE_ACCURACY=1`) and skipped when the model is unavailable. For each `ScanFixtureTruth`, read with `InBodyIntelligenceReader(locator: VisionSectionLocator(), sections: FoundationModelsSectionReader(), fallback: <a reader that fails the test if called>)`, print a per-sheet scorecard (wrong and blank lines only, seconds taken) through `XCTContext`/attachments or `Log`, and assert:
  - `testCoreValues`: the seven core values equal truth on every sheet (tolerance 0.05; BMR 0.5).
  - `testOtherSections`: every non-segmental-lean value equals truth (tolerance 0.0006); a nil is allowed only where `isMisprinted`.
  - `testDates`: `scanDate` matches `testDate` where truth has one; where truth is nil the result's date is nil or flagged by the window.
  - `testSegmentalLean`: on sheets with `isMisprinted == false` every segmental lean value equals truth; on the misprinted sheet each value equals truth, is nil, or has confidence below 0.70. Marked with `XCTExpectFailure` until Task 8.

- [ ] **Step 1:** Write `IntelligenceAccuracyTests`; RUN with the flag → fails to compile (adapters missing).
- [ ] **Step 2:** Implement the three files. `make generate`.
- [ ] **Step 3:** RUN with the flag. Iterate on crops and prompts until `testCoreValues`, `testOtherSections` and `testDates` pass. Do not loosen an assertion to get there; if one cannot be met, stop and report the scorecard to Ben.
- [ ] **Step 4:** RUN without the flag → the class is skipped; RUN `InBodyIntelligenceReaderTests` → still passes.
- [ ] **Step 5:** Commit `feat: Vision section locator and on-device section reader (#49)`.

### Task 8: Segmental lean to the bar

**Files:** Modify `SectionLayout.swift`, `SectionSchemas.swift`, `FoundationModelsSectionReader.swift`, and `VisionSectionLocator.swift` if row labels are needed; Tests: `SectionLayoutTests`, `IntelligenceAccuracyTests`.

What the spike showed: one question for all ten numbers swaps lbs and % and merges digits; a crop per body part reads the neighbouring row when the crop is a row off; the three templates in the fixtures place a row's numbers differently relative to its label, so one fixed offset from the label cannot isolate a row on all of them.

- [ ] **Step 1:** Remove the `XCTExpectFailure` from `testSegmentalLean`; RUN with the flag → fails; save the scorecard.
- [ ] **Step 2:** Try, in this order, keeping whichever first meets the bar and adding a unit test for any new pure geometry:
  1. Row crops bounded by consecutive row labels ("Right Arm", "Left Arm", "Trunk", "Right Leg", "Left Leg", left column, inside the segmental lean band) with generous overlap, and a prompt that names the row to read.
  2. Crops of the value column only (the right-hand end of the bars), one per row, so neighbouring labels and tick marks are out of frame.
  3. Ask for the section's result numbers as an ordered list top to bottom, then pair them in code using the sane ranges (lbs vs %).
- [ ] **Step 3:** RUN with the flag → all four accuracy tests pass. If none of the three approaches meets the bar, stop: bring Ben the scorecards and the options in the spec (for example, leaving this section blank on the model path).
- [ ] **Step 4:** Commit `feat: read segmental lean rows individually (#49)`.

### Task 9: Selection, wiring, guard

**Files:**
- Create: `Baseline/OCR/ScanPageReaderSelector.swift`
- Modify: `Baseline/ViewModels/ScanEntryViewModel.swift` (default `makePageReader`; call `prepare()` when the step becomes `.camera`), `.swiftlint.yml` (custom rule)
- Test: `BaselineTests/OCR/ScanPageReaderSelectorTests.swift`, `BaselineTests/ViewModels/ScanEntryViewModelTests.swift`

**Interfaces — Produces:**
```swift
enum ScanPageReaderSelector {
    static func reader(modelIsAvailable: Bool, modelSeesImages: Bool) -> any ScanPageReading
    static func current() -> any ScanPageReading   // reads SystemLanguageModel.default availability and .vision capability
}
```
`reader` returns `InBodyIntelligenceReader(locator: VisionSectionLocator(), sections: FoundationModelsSectionReader(), fallback: ParserPageReader())` only when both flags are true; otherwise `ParserPageReader()`. The view model's default becomes `makePageReader: ScanPageReaderSelector.current`.

Lint rule, next to `no_print`:
```yaml
  no_private_cloud_compute:
    name: "On-device model only"
    regex: 'PrivateCloudComputeLanguageModel'
    message: "Scans never leave the device. Use SystemLanguageModel.default."
    severity: error
```

- [ ] **Step 1: Failing tests**
  - `testIntelligenceOnlyWhenAvailableAndSeesImages`: (true, true) → `InBodyIntelligenceReader`; (true, false), (false, true), (false, false) → `ParserPageReader`.
  - In `ScanEntryViewModelTests`: `testLoneIntelligenceResultIsNotFlagged` (fake reader returns `isSelfValidated` result, weight 199.4 at 0.9, with a full consistent set for the cross-field checks → `lowConfidenceFields` does not contain `weightKg`); `testFlaggedIntelligenceValueIsFlagged` (confidence 0.3 → contained); `testRescanKeepsUserEdits` (two `processPages` calls with a user edit between them → the edited field keeps the user's text); `testEnteringCameraPreparesReader` (fake records `prepare()` once).
- [ ] **Step 2–4:** RUN fails → implement → RUN `ScanPageReaderSelectorTests`, `ScanEntryViewModelTests` pass. `make generate`. `make lint` passes, and adding a line containing `PrivateCloudComputeLanguageModel` to any app file makes it fail (then remove the line).
- [ ] **Step 5:** Commit `feat: use the on-device model for scans when available (#49)`.

### Task 10: Whole-change verification

- [ ] **Step 1:** `make lint` → no violations.
- [ ] **Step 2:** Parser path unchanged: on this branch and on `main`, RUN `InBodyDocumentParserFixtureTests` with `TEST_RUNNER_RUN_OCR_STRICT=1` and compare the printed per-field tables for `clean`, `marked` and `review-sample` → identical. Confirm `git diff main -- Baseline/OCR/InBodyDocumentParser.swift Baseline/OCR/CrossFieldValidator.swift` is empty.
- [ ] **Step 3:** RUN `IntelligenceAccuracyTests` with the flag → all pass; keep the scorecard for the PR.
- [ ] **Step 4:** Dispatch the `ios-verifier` agent for `make build` and `make test` evidence. `SetGoalFlowUITests` failing is the known local failure; anything else is ours.
- [ ] **Step 5:** Ask Ben to run a real scan on their phone through the app (document camera, not a flat PDF) and to run `IntelligenceAccuracyTests` on the device; record time per page and any wrong value.
- [ ] **Step 6:** `git status --short` → only `.serena/project.yml` unstaged. Report to Ben: what was verified, the scorecards, anything skipped, and the findings listed in the spec that remain open.
