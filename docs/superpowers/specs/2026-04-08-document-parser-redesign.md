# InBody OCR: RecognizeDocumentsRequest Migration

## Goal

Replace the regex-based full-page OCR parser with iOS 26's `RecognizeDocumentsRequest` for structured table extraction. Replace the custom camera with Apple's `VNDocumentCameraViewController`. Keep old parser code as inactive fallback.

## Architecture

**Capture:** `VNDocumentCameraViewController` wrapped in a SwiftUI `UIViewControllerRepresentable` (`DocumentScannerView`). Handles edge detection, perspective correction, and image cleanup automatically. Returns a `UIImage`.

**Extract:** New `InBodyDocumentParser` runs `RecognizeDocumentsRequest` on the captured image. Walks detected tables to find label-value pairs, then falls through to paragraph text for values not found in tables. Maps everything to the existing `InBodyParseResult`.

**Review:** Existing `ScanEntryFlow` review screen. Editable fields, retry, save. No changes needed.

**Old code:** `InBodyOCRParser.swift`, `ScanCameraView.swift`, `DocumentCorrector.swift`, `InBody570RegionMap.swift`, `InBody570RegionParsers.swift` remain in the project as dead code. Not called from any active code path. Available to wire up as fallback later if needed.

## Scope

- InBody 570 only (same as current)
- iOS 26+ deployment target (already set)
- On-device only, no network calls
- No new dependencies

## Components

### New Files

**`Baseline/OCR/InBodyDocumentParser.swift`**

The new extraction engine. Single public entry point:

```swift
struct InBodyDocumentParser {
    static func parse(image: UIImage) async -> InBodyParseResult
}
```

Internally:
1. Convert UIImage to CGImage
2. Run `RecognizeDocumentsRequest().perform(on: cgImage)`
3. Walk `document.tables` — for each table, iterate rows looking for label-value pairs
4. Walk `document.paragraphs` — catch standalone values not in tables (e.g., InBody Score, BMR)
5. Check `document.tables[n].rows[n][n].content.detectedData` for date extraction
6. Map recognized labels to `InBodyParseResult` field keys using a label-to-key dictionary
7. If observation-level confidence works (non-zero), use it; otherwise skip confidence

**Label matching strategy:** The InBody sheet uses consistent labels like "Weight", "Skeletal Muscle Mass", "BMI", "Percent Body Fat", etc. The parser maintains a dictionary mapping known label strings (and common OCR variants) to `InBodyParseResult` field keys. For table rows, the first cell is treated as the label and subsequent cells as values. For paragraphs (fallback), the parser looks for "Label Value" or "Label: Value" patterns in transcript text. The table path handles the majority of fields; paragraph fallback catches standalone metrics like InBody Score or BMR that may not be in a detected table.

**`Baseline/Views/Body/DocumentScannerView.swift`**

UIViewControllerRepresentable wrapping `VNDocumentCameraViewController`:
- `onScan: (UIImage) -> Void` callback with the captured image
- `onCancel: () -> Void` callback
- Handles the `VNDocumentCameraViewControllerDelegate` methods
- Simulator support: VNDocumentCameraViewController works in simulator with photo library

### Modified Files

**`Baseline/ViewModels/ScanEntryViewModel.swift`**

- Change `processImage()` to call `InBodyDocumentParser.parse(image:)` instead of `InBodyOCRParser.processImage()`
- Everything else unchanged (populateFields, mergeRetryResult, save, state machine)

**`Baseline/Views/Body/ScanEntryFlow.swift`**

- Replace the `.camera` step's `ScanCameraView` with `DocumentScannerView`
- The step flow simplifies: selecting "camera" now presents Apple's doc scanner directly
- On scan completion, advance to `.review` step
- On cancel, go back to `.selectMethod`

### Unchanged Files

- `InBodyParseResult.swift` — data model stays the same
- `ScanPayloads.swift` — no changes
- `ScanEntryViewModelTests.swift` — tests populateFields/flow, not the parser directly
- `ScanDetailView.swift` — displays saved data, no changes

### Dead Code (kept, not called)

- `InBodyOCRParser.swift` (560 lines) — old regex parser
- `ScanCameraView.swift` (382 lines) — custom AVCaptureSession camera
- `DocumentCorrector.swift` (74 lines) — perspective correction (doc camera does this now)
- `InBody570RegionMap.swift` (35 lines) — region coordinates
- `InBody570RegionParsers.swift` (306 lines) — per-region text parsers

## Data Flow

```
User taps "Scan" → selectType (.inBody) → selectMethod (camera: true)
    → Present VNDocumentCameraViewController
    → User captures sheet, Apple handles edge detection + perspective correction
    → UIImage returned via delegate
    → InBodyDocumentParser.parse(image:)
        → RecognizeDocumentsRequest.perform(on: cgImage)
        → Walk tables: match labels to values
        → Walk paragraphs: catch remaining values
        → Extract scan date from detectedData
        → Return InBodyParseResult
    → ScanEntryViewModel.populateFields(from: result)
    → Review screen with editable fields
    → User verifies/edits → Save
```

## Confidence Scoring

`RecognizeDocumentsRequest` has an observation-level `confidence` property. Reports suggest it currently returns 0.0 (bug). Implementation approach:

1. Read the confidence value
2. If non-zero, populate `InBodyParseResult.confidence` dictionary as before
3. If zero, leave confidence empty — the review screen still shows all fields as editable, just without amber low-confidence highlighting
4. No fallback to `RecognizeTextRequest` for confidence — keep it simple

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No tables detected | Fall through to paragraph parsing. If still empty, show error with manual entry option. |
| Partial extraction (<7 required fields) | Show review screen with what we got. Missing fields shown with dashed borders. User fills in manually. |
| Camera cancelled | Dismiss back to selectMethod step. |
| RecognizeDocumentsRequest throws | Show error message, offer manual entry. |

## Retry Flow

Unchanged from current design:
1. User taps "Retry" on review screen
2. Apple doc scanner presents again
3. New image parsed via `InBodyDocumentParser`
4. `mergeRetryResult()` merges new values, preserving user edits
5. `retryCount` increments

## Testing

- **Unit test `InBodyDocumentParser`**: Test the label-matching logic and value parsing with known input strings. The RecognizeDocumentsRequest itself can't be easily mocked, but the label→field mapping logic can be extracted and tested independently.
- **Existing tests pass**: `ScanEntryViewModelTests` test the ViewModel layer (populateFields, flow, save) which doesn't change.
- **Manual testing**: Scan a real InBody 570 sheet on a physical device to verify end-to-end extraction.
