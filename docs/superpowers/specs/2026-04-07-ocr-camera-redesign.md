# InBody 570 OCR, Camera UI & Confidence Flagging

## Goal

Rebuild the scan capture experience to reliably extract all ~35 fields from an InBody 570 result sheet, provide a custom camera UI with alignment guidance, flag low-confidence reads for user review, and support a smart retry flow when fields are missed.

## Scope

- InBody 570 only (architecture supports future scan types via per-model parsers)
- Camera capture, OCR extraction, confidence scoring, review screen, retry flow
- Model expansion (new fields on InBodyPayload)
- No changes to manual entry flow (already works)

## Mockups

- Camera UI: `docs/mockups/scan-camera-ui-2026-04-07.html`
- Review screen: `docs/mockups/scan-review-ui-2026-04-07.html`

---

## 1. Camera UI

### States

**Framing** — dashed rectangle with accent corner brackets. Status hint: "Align sheet within frame". White shutter button.

**Ready** — corner brackets turn green, dashed guide becomes solid. Hint: "Good — tap to capture". Shutter ring turns green. Triggered by detecting a rectangular document in the viewfinder via `VNDetectDocumentSegmentationRequest`.

**Processing** — dark overlay with spinner. "Processing scan..." / "Extracting values from image".

### Implementation

Replace `CameraView` (current UIImagePickerController wrapper) with a custom `AVCaptureSession`-based view:
- Live preview layer with overlay guide frame
- Real-time document detection using Vision (`VNDetectDocumentSegmentationRequest`) for the ready state
- Manual shutter button (no auto-capture)
- Close button (top-left)
- No tab bar (fullScreenCover)
- Simulator fallback: photo picker (existing pattern)

---

## 2. Region-Based OCR (InBody 570)

### Why

The current text-based parser gets ~4/22 fields because:
1. Multi-column layout confuses line-by-line parsing
2. Bar chart range numbers get extracted instead of actual values
3. Field labels don't match expected keywords
4. No confidence scoring

### Approach

1. **Perspective correction** — use `VNDetectDocumentSegmentationRequest` to find the sheet's four corners, then apply a perspective transform (Core Image `CIPerspectiveCorrection`) to produce a flat, normalized image.

2. **Region cropping** — define a `InBody570RegionMap` struct with normalized bounding boxes (0–1 coordinate space) for each section of the standardized InBody 570 layout. Crop the corrected image into ~10 independent region images.

3. **Per-region OCR** — run `VNRecognizeTextRequest` on each cropped region independently. This eliminates cross-section number confusion.

4. **Per-region parsing** — each region gets a specialized parser that knows the field order and expected format for that section. For example, the "Body Composition Analysis" region parser knows it will see six label-value pairs in order: ICW, ECW, TBW, Dry Lean Mass, LBM, Body Fat Mass.

5. **Confidence scoring** — Vision's `VNRecognizedTextObservation` provides a `confidence` float (0–1) per recognized text block. Each field's confidence is the confidence of the observation from which its value was extracted. If a field's value spans multiple observations, use the minimum confidence. Threshold: 0.7 (below = flagged as low confidence).

### InBody 570 Region Map

| Region | Section | Fields |
|--------|---------|--------|
| R1 | Header | Scan date |
| R2 | Body Composition Analysis | ICW, ECW, TBW, Dry Lean Mass, LBM, Body Fat Mass |
| R3 | Muscle-Fat Analysis | Weight, SMM, Body Fat Mass |
| R4 | Obesity Analysis | BMI, PBF |
| R5 | Segmental Lean Analysis | 5 segments x (mass + sufficiency %) |
| R6 | ECW/TBW Analysis | ECW/TBW ratio |
| R7 | Segmental Fat Analysis | 5 segments x (mass + sufficiency %) |
| R8 | BMR | Basal Metabolic Rate |
| R9 | SMI | Skeletal Muscle Index |
| R10 | Visceral Fat | Visceral Fat Level |

### Unit Detection

The InBody 570 prints values in either lbs or kg depending on facility configuration. The parser detects which unit system by checking the "Weight" field's label suffix or nearby unit indicator, then applies conversion as needed. All values are stored in kg/L internally. If the unit system cannot be determined, default to lbs (US facilities are the majority of InBody installations) and flag the unit detection as low-confidence so the user can verify.

### Duplicate Field Cross-Check

Body Fat Mass appears in both R2 (Body Composition Analysis) and R3 (Muscle-Fat Analysis). If both are extracted, use the higher-confidence value. If only one is found, use it.

---

## 3. Confidence Flagging & Review Screen

### Field States

| State | Visual | Condition |
|-------|--------|-----------|
| Normal | White text, card background | Confidence >= 0.7 |
| Low confidence | Amber border + text, amber card | Confidence < 0.7 |
| Missing | Gray "--", dashed border, unit visible | Field not extracted |

### Review Screen Layout

- **Date chip** (top) — extracted from sheet header, tappable to change. Matches existing WeighIn/ScanDetail chip style.
- **Warning banner** — "N fields may need review". Only shown when low-confidence fields exist. Simple text, no action button.
- **Field sections** — ordered to mirror InBody 570 printout:
  1. Body Composition Analysis
  2. Muscle-Fat Analysis
  3. Obesity Analysis
  4. Segmental Lean Analysis (table: segment / mass / suff. %)
  5. ECW/TBW
  6. Segmental Fat Analysis (table: segment / mass / suff. %)
  7. Additional Metrics (BMR, SMI, Visceral Fat)
- **All values editable** — each value sits in a card-background cell signaling tappability. Tap opens decimal pad keyboard. Missing fields show dashed border with unit label visible.
- **Save button** — disabled (gray) when required fields (the 7 core InBodyPayload fields) are missing.

### Retry Banner

When fields are missing, an inline banner appears: "Some fields couldn't be read" + "Retry Scan" button. Tapping retry returns to the camera.

---

## 4. Retry Flow

1. **First capture** — full-page photo with guided camera UI.
2. **OCR runs** — region-based extraction. Check results.
3. **If fields missing (attempt 1)** — show review screen with retry banner: "Some fields couldn't be read" + "Retry Scan". User retakes full-page photo.
4. **If same fields still missing (attempt 2)** — retry banner changes to targeted: "Zoom in on [section name]". Shows a reference thumbnail indicating which part of the sheet to photograph. Camera guide frame shrinks to match the target section.
5. **After any retry** — newly extracted values merge with existing results (higher confidence wins). User-edited values are never overwritten by retry results — only fields still showing OCR-extracted or missing values are eligible for merge. User reviews final merged result.
6. **User can always skip retry** — tap missing fields to enter values manually. Save enables once required fields are present.

---

## 5. Model Changes

### InBodyPayload Expansion

New fields to add (all optional):

```swift
// ECW/TBW
var ecwTbwRatio: Double?

// SMI & Visceral Fat
var skeletalMuscleIndex: Double?
var visceralFatLevel: Double?

// Segmental sufficiency percentages (lean)
var rightArmLeanPct: Double?
var leftArmLeanPct: Double?
var trunkLeanPct: Double?
var rightLegLeanPct: Double?
var leftLegLeanPct: Double?

// Segmental sufficiency percentages (fat)
var rightArmFatPct: Double?
var leftArmFatPct: Double?
var trunkFatPct: Double?
var rightLegFatPct: Double?
var leftLegFatPct: Double?
```

This brings InBodyPayload from 22 to ~35 fields. All new fields are optional, so existing saved scans remain compatible (Codable defaults to nil). No SwiftData migration required.

### InBodyParseResult Expansion

Mirror all new InBodyPayload fields. Add confidence dictionary population during parsing. Add `scanDate: Date?` field for the date extracted from the sheet header (R1). This flows into `Scan.date` (not InBodyPayload) — the ViewModel uses the parsed date as the default, and the user can override via the date chip.

### Old Parse Path

The existing `InBodyOCRParser.parse(_ text: String)` method and `recognizeText(from:)` are replaced by the region-based approach. The old text-based path is removed (not kept as fallback) since it only captures ~4/22 fields and adds maintenance burden.

---

## 6. Architecture

```
CameraView (AVCaptureSession + guide overlay)
    ↓ UIImage
ScanEntryViewModel.processImage()
    ↓
InBody570RegionMap.crop(correctedImage)
    ↓ [RegionImage]
InBodyOCRParser.parseRegions([RegionImage])
    ↓ InBodyParseResult (with confidence scores)
ScanEntryViewModel.populateFields()
    ↓ flags lowConfidenceFields
Review Screen (ScanEntryFlow)
    ↓ user edits / retries
ScanEntryViewModel.save()
    ↓ InBodyPayload → Scan
```

### Key Files

| File | Change |
|------|--------|
| `CameraView.swift` | Rewrite: AVCaptureSession + guide overlay + document detection |
| `InBodyOCRParser.swift` | Rewrite: region-based extraction + confidence scoring |
| `InBody570RegionMap.swift` | New: bounding box definitions + crop logic |
| `ScanEntryViewModel.swift` | Update: retry state machine, merge logic |
| `ScanEntryFlow.swift` | Update: review screen with new field layout, retry UI |
| `ScanPayloads.swift` | Update: add ~13 new optional fields |
| `ScanDetailView.swift` | Update: display new fields |

### What We're NOT Changing

- Manual entry flow (already works, separate path)
- Scan model structure (type discriminator + Data payload)
- ScanType/ScanSource enums
- Body tab tiles or Trends integration (they read from InBodyPayload, new fields just show up)

---

## 7. Testing

- **InBodyOCRParser unit tests** — test each region parser with known text inputs. Test confidence thresholds. Test unit detection (lbs vs kg).
- **Region map tests** — verify bounding boxes produce correct crops on a reference InBody 570 image.
- **ViewModel tests** — test retry state machine, field merging, low-confidence flagging.
- **Snapshot tests** — review screen in all 3 states (happy path, segmental scroll, retry prompt).
- **Integration test** — full pipeline from reference image → parsed result with known expected values.

---

## 8. Intentionally Excluded

- **Body Composition History** section (bottom of sheet) — we track this ourselves via scan history.
- **Body Fat - Lean Body Mass Control** section (right column) — these are recommendations/targets, not measurements.
- **InBody Score** — not present on all InBody 570 printouts. Keep existing optional field but don't add to region map. If detected during parsing, capture it.
- **Auto-capture** — manual shutter keeps user in control.
- **Multiple scan type support** — architecture supports it (per-model region maps), but only InBody 570 is implemented now.
- **Targeted zoom retry (attempt 2)** — stretch goal. The full-page retry + manual entry fallback covers the critical path. Targeted zoom can be added later if users frequently hit the same missing sections.

---

## 9. Technical Notes

- **Memory pressure** — run the 10 per-region `VNRecognizeTextRequest` calls sequentially (not concurrently) to avoid peak memory spikes on older devices.
- **Camera permissions** — `AVCaptureSession` requires explicit `AVCaptureDevice.requestAccess(for: .video)`. Handle denied/restricted states in the camera UI with a message directing to Settings. `NSCameraUsageDescription` already exists in Info.plist.
- **Sheet orientation** — users may photograph the sheet in landscape. The perspective correction via `VNDetectDocumentSegmentationRequest` handles rotation — ensure the corrected output is normalized to portrait orientation before cropping regions.
- **Region map calibration** — the normalized bounding boxes for R1-R10 will need calibration against multiple InBody 570 printouts. Start with coordinates derived from the reference photo, then refine with 2-3 additional samples.
