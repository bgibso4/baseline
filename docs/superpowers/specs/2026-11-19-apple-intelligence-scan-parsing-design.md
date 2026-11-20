# Apple Intelligence scan parsing — design (issue #49)

Date: 2026-11-19. Status: approved by Ben 2026-11-19; amended 2026-11-20 (see Amendments).

## Why

Scans too often produce values that are wrong but look trustworthy, or come back blank. On Ben's eight real
scans today's parser got 39% of the sheet's 34 values right; body fat % was missed or misread on every one.
A wrong value saved silently corrupts someone's health history, which is the one thing this feature must not do.

## What we are building

When Apple Intelligence is available, the on-device model reads the scan photo, one section at a time, and
fills the existing review form. When it is not available, the app behaves exactly as it does today.

### Goals

- Correct values on real InBody 570 sheets, including creased, pen-marked and misprinted ones.
- A value the model cannot read well is blank or flagged, never silently wrong.
- Today's parser path is byte-for-byte unchanged in behaviour and is not run when the model path runs.
- The model path is small and self-contained, so the old parser can be deleted later in one move.

### Non-goals

- Deleting or improving `InBodyDocumentParser`, including its scan-date bug (see Findings).
- Redesigning the review screen. No UI mocks; the flow and its controls stay as they are.
- Other sheet layouts or other InBody models.
- Any SwiftData or CloudKit schema change. None is needed.

### Anti-goals

- Scan images or values leaving the device. `PrivateCloudComputeLanguageModel` and every network path are
  off-limits. The privacy policy, the App Store "Data Not Collected" label, `PrivacyInfo.xcprivacy` and
  `docs/APP_REVIEW_NOTES.md` must stay true without edits.
- Accuracy on the model path that depends on the old parser's heuristics.
- Widening a lint threshold to fit the new code.

## Evidence (throwaway spike, branch `spike/49-foundation-models-vision`)

Eleven sheets: three repo fixtures and eight flat scans of Ben's printouts (six distinct sheets). Run on the
iPhone 17 simulator, Xcode 27.2. Ground truth was read off the images by Claude; Ben to spot-check.

| Reader | Right | Wrong | Blank |
|---|---|---|---|
| Model, whole photo, 7 core values | 11 of 21 | 10 | 0 |
| Model, section by section, 7 core values | 77 of 77 | 0 | 0 |
| Model, section by section, all 34 values | 317 of 347 | 26 | 4 |
| Today's parser, all 34 values | 137 of 347 | 126 | 84 |

What the spike taught us:

- **Show the model less.** A whole page is downsampled until small print blurs. A crop of one section, with a
  question about only that section, is what works. Asking for seven values from one table was worse than two
  questions of three and four.
- **The model invents values rather than leaving blanks**, even when told not to. Plausibility has to be
  checked outside the model.
- **Segmental lean is the weak section**: 24 of the 26 wrong values. Ten numbers in two interleaved rows per
  body part; the model reads a neighbouring row or swaps lbs and %.
- **Misprinted sheets** (data printed out of register with the form) defeat the header date and one struck-
  through value.
- **Apple's guardrail refused one harmless crop.** A section can fail on its own.
- **Images must be 8-bit sRGB.** Extended-range camera JPEGs failed to convert and the model silently saw
  nothing.
- **Speed is unknown.** Sixteen questions took 17–45 s per page on the simulator, varying run to run.

## Approaches considered

1. **Model reads; parser only when the model is unavailable.** Chosen by Ben. Flags come from the sheet's own
   redundancy and arithmetic. The parser is frozen and removable later.
2. **Model reads; parser double-checks every scan.** Rejected: the parser is wrong or blank so often on real
   pages that most disagreements would be its fault, and it would stay load-bearing forever.
3. **Parser reads; model fills gaps.** Rejected: the evidence says the model is the better reader.

Ben's words on 1: "If Apple Intelligence is available I don't even want to touch our parser logic."

## Design

### Choosing a reader

A small protocol, `ScanPageReading` — "turn one page image into an `InBodyParseResult`" — with two
conformances: a thin wrapper over the existing `InBodyDocumentParser.parse(image:)`, and the new
`InBodyIntelligenceReader`. `ScanEntryViewModel` receives a reader by injection instead of calling the static
parser. Selection happens once per scan attempt:

- `SystemLanguageModel.default.availability == .available` **and** its capabilities include `.vision` → the
  intelligence reader.
- Anything else (device not eligible, Apple Intelligence off, model not ready) → the parser, as today.

No message about Apple Intelligence is shown in either case.

### The intelligence reader

New code lives in `Baseline/OCR/Intelligence/`, one type per file:

1. **Prepare the image.** Re-render to 8-bit sRGB. The view model's existing 2048 px downscale stays.
2. **Locate sections.** Vision's `RecognizeDocumentsRequest` finds the printed section headings. A pure
   function fits the found headings to a reference layout (scale and offset) and predicts any heading Vision
   missed, then returns one crop rectangle per section. This uses Vision text recognition but none of the
   parser's code. If fewer than two headings are found, the page is unreadable (see Failure handling).
3. **Ask per section.** One fresh `LanguageModelSession` and one small `@Generable` type per question, greedy
   sampling, with the crop attached. Core sections go first. The model call sits behind a narrow protocol so
   the reader can be unit-tested with a fake.
4. **Assemble and check.** Values go into an `InBodyParseResult`. Each value is then checked (next section).

### Trust and flags

The model gives no confidence, so trust comes from checks we can explain:

- **Range.** A value outside `InBodyParseResult.SaneRange` for its field is dropped to blank.
- **Printed twice.** Weight and body fat mass appear in both the table and the bar chart. If the two reads
  differ, both fields are flagged.
- **Arithmetic.** The existing `CrossFieldValidator` identities run as they do today.
- **Date.** A test date in the future or more than five years old is dropped.

A value that passes gets a confidence above the review threshold; a flagged one gets a confidence below it.
The existing rule that caps every field of a lone scan at 0.4 exists because one parser pass is not
trustworthy. It must keep applying to parser results and must not apply to intelligence results. How that
distinction is carried is left to the builder, with one constraint: parser-path behaviour does not change.

Multi-page scans and "scan again" keep using the existing consensus vote.

### Failure handling

- **One section fails** (guardrail refusal, generation error): its fields are blank; other sections stand. The
  error is logged with `Log.scan.error`.
- **The model cannot run at all** (availability changes mid-scan, assets unavailable): fall back to the parser
  for that page.
- **The page is unreadable by the model path** (fewer than two headings): fall back to the parser for that
  page. *Claude's call.* It is the same situation as the model being unavailable, and it beats an empty form.
- Which reader produced a result is logged.

### Privacy guard

Only `SystemLanguageModel.default` is used. A custom SwiftLint rule bans `PrivateCloudComputeLanguageModel`
in app sources, alongside the existing no-`print` rule. *Claude's call.*

### Speed

Unknown until measured on a phone, so it is a gate, not an assumption:

- The first build milestone is a device timing harness. Ben runs it on their phone.
- If a full page takes about ten seconds or less, all sections are read before the review form appears, behind
  the existing processing state.
- If it takes longer, we stop and decide with Ben between showing the form after the core sections and filling
  the rest in as it arrives, or reading fewer sections. That would be a UI change and is not designed here.
- The session is prewarmed when the camera step opens.

## Testing

- **Fixtures.** Ben approved adding their scans. The six distinct sheets go into
  `BaselineTests/Fixtures/Scans/` as JPEGs, with full 34-value ground truth in the test.
  `review-sample.jpg` gets full ground truth too; today only its seven core values are recorded.
- **CI (no model needed).** Unit tests for the heading fit and crop geometry, result assembly, the range,
  twice-printed and date checks, reader selection, per-section failure, and fallback. All use the fake model.
  CI simulators without Apple Intelligence keep exercising the parser path, so existing tests are unaffected.
- **Accuracy suite (needs the model).** Gated by an environment flag like the existing strict OCR tests, and
  skipped when the model is unavailable. It prints a scorecard and asserts the bar below.

### Done means

On the fixture set, through the model path:

- The seven core values: all right on every sheet.
- Every other section except segmental lean: no wrong values. Blanks are acceptable only on the misprinted
  08-04 sheet.
- Segmental lean: every value right on the sheets that are not misprinted; on the misprinted sheet, any value
  that is not right is blank or flagged.
- `review-sample.jpg`: every value right, since App Review may run it on a device with Apple Intelligence.
- With the model unavailable, results are identical to `main`.
- `make lint` and `make test` pass; `ios-verifier` supplies the build and test evidence.

If the segmental lean bar cannot be met, we stop and bring Ben options (for example, leaving that section
blank for manual entry on the model path) rather than shipping below it.

## Left to the builder

- Exact crop geometry and prompts, driven by the accuracy suite. Segmental lean needs a better approach than
  the spike's row crops.
- File and type names inside `Baseline/OCR/Intelligence/`.
- How intelligence results are exempted from the lone-scan confidence cap.

## Findings outside this work

- Today's parser returned today's date (with the sheet's time of day) as the scan date on 8 of Ben's 10 real
  sheets in the spike. Not fixed here; worth its own issue.
- `ScanEntryViewModel.populateFields` carries its own table of sane ranges that duplicates
  `InBodyParseResult.SaneRange`. Not touched here.
- On a lone parser scan every field is flagged, because of the 0.4 cap. Unchanged on the parser path.

## Amendments (2026-11-20, from building it and running on Ben's iPhone 16 Pro)

Decisions by Ben:

- **One page on the model path.** When the model reads, only the first captured page is read; the parser path
  still reads and compares every page. The "multiple photos" tip and hint and the "single photo" banner are
  hidden when they do not apply.
- **The loading screen is out of scope here.** A page takes 15–25 s, so a dedicated screen is needed, but it
  belongs to the redesign in progress. This work keeps the existing "Reading scan..." overlay.
- **Speed gate missed.** Measured 22–28 s per page read one section at a time (1.3–3.6 s per question, under 1 s
  to locate sections). Concurrent reads measured 15–19 s on one sheet; a larger test decides whether and how to
  adopt them.

What changed from the design above:

- **The simulator is not representative.** The phone's model makes different mistakes from the simulator's.
  Accuracy is tuned and judged on a device.
- **Sections.** The body-composition table is read as two crops (values, totals). Segmental lean and segmental
  fat are read as plain lists of numbers that code pairs and range-checks, all or nothing; five lean numbers
  that are all masses or all percentages are accepted as that one column. BMR and SMI use a narrow crop around
  the printed value.
- **Rate limiting.** The system refuses model requests once the phone locks or the app is backgrounded. A
  rate-limited page falls back to the parser, like an unavailable model.
- **Timing logs.** The reader logs total, locate and per-section times for each page.

Latest device scorecard (nine fixtures): no wrong values; dates and all other sections right; BMR blank on
`clean.jpg`; segmental lean blank on `review-sample.jpg`. Both are open against the done bar.

Additional finding outside this work: a debug build crashed on the phone with a main-thread stack overflow
building `ScanReviewForm` (`reviewValueCell`); an optimized build did not. Not verified against `main`.
