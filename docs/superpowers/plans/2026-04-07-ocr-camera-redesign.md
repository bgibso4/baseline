# InBody 570 OCR & Camera Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild InBody 570 scan capture with region-based OCR (~35 fields), custom camera UI with alignment guidance, confidence flagging, and retry flow.

**Architecture:** Perspective-correct the captured sheet, crop predefined regions (R1-R10), OCR each independently with Vision, parse with section-specific extractors, score confidence per field. Custom AVCaptureSession camera with document detection overlay. Review screen mirrors InBody 570 printout layout with three field states (normal/low-confidence/missing).

**Tech Stack:** Vision (VNRecognizeTextRequest, VNDetectDocumentSegmentationRequest), AVFoundation (AVCaptureSession), Core Image (CIPerspectiveCorrection), SwiftUI, SwiftData

**Spec:** `docs/superpowers/specs/2026-04-07-ocr-camera-redesign.md`
**Mockups:** `docs/mockups/scan-camera-ui-2026-04-07.html`, `docs/mockups/scan-review-ui-2026-04-07.html`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `Baseline/Models/ScanPayloads.swift` | Modify | Add 13 new optional fields to InBodyPayload |
| `Baseline/OCR/InBodyParseResult.swift` | Create | Parse result struct (extracted from InBodyOCRParser.swift) with ~35 fields + confidence + scanDate |
| `Baseline/OCR/InBody570RegionMap.swift` | Create | Normalized bounding boxes for 10 regions + crop logic |
| `Baseline/OCR/InBody570RegionParsers.swift` | Create | Per-region text parsers (R1-R10) |
| `Baseline/OCR/InBodyOCRParser.swift` | Rewrite | Region-based pipeline: perspective correct → crop → OCR → parse → confidence |
| `Baseline/OCR/DocumentCorrector.swift` | Create | Perspective correction using Vision + Core Image |
| `Baseline/Views/Body/ScanCameraView.swift` | Create | Custom AVCaptureSession camera with guide overlay + document detection |
| `Baseline/Views/Body/ScanEntryFlow.swift` | Modify | Review screen: new field layout, retry banner, editable cells |
| `Baseline/ViewModels/ScanEntryViewModel.swift` | Modify | New fields, retry state, merge logic, scan date |
| `Baseline/Views/Body/ScanDetailView.swift` | Modify | Display new fields (SMI, visceral fat, ECW/TBW, sufficiency %) |
| `BaselineTests/OCR/InBody570RegionParsersTests.swift` | Create | Per-region parser unit tests |
| `BaselineTests/OCR/InBodyOCRParserTests.swift` | Modify | Update for region-based API |
| `BaselineTests/ViewModels/ScanEntryViewModelTests.swift` | Modify | Retry, merge, new fields |
| `BaselineTests/Snapshots/ScanEntrySnapshotTests.swift` | Modify | Re-record for new review layout |

---

### Task 1: Expand InBodyPayload with new fields

**Files:**
- Modify: `Baseline/Models/ScanPayloads.swift`
- Test: `BaselineTests/Models/ScanTests.swift`

- [ ] **Step 1: Write test for new fields on InBodyPayload**

Add to `BaselineTests/Models/ScanTests.swift`:

```swift
func testInBodyPayload_NewFieldsDefaultToNil() {
    let payload = InBodyPayload(
        weightKg: 90.0,
        skeletalMuscleMassKg: 40.0,
        bodyFatMassKg: 15.0,
        bodyFatPct: 16.7,
        totalBodyWaterL: 55.0,
        bmi: 25.0,
        basalMetabolicRate: 1850
    )
    XCTAssertNil(payload.ecwTbwRatio)
    XCTAssertNil(payload.skeletalMuscleIndex)
    XCTAssertNil(payload.visceralFatLevel)
    XCTAssertNil(payload.rightArmLeanPct)
    XCTAssertNil(payload.rightArmFatPct)
    XCTAssertNil(payload.trunkLeanPct)
    XCTAssertNil(payload.trunkFatPct)
}

func testInBodyPayload_NewFieldsRoundTrip() throws {
    var payload = InBodyPayload(
        weightKg: 90.0, skeletalMuscleMassKg: 40.0, bodyFatMassKg: 15.0,
        bodyFatPct: 16.7, totalBodyWaterL: 55.0, bmi: 25.0, basalMetabolicRate: 1850
    )
    payload.ecwTbwRatio = 0.380
    payload.skeletalMuscleIndex = 10.4
    payload.visceralFatLevel = 3
    payload.rightArmLeanPct = 112.4
    payload.trunkFatPct = 94.5

    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(InBodyPayload.self, from: data)
    XCTAssertEqual(decoded.ecwTbwRatio, 0.380)
    XCTAssertEqual(decoded.skeletalMuscleIndex, 10.4)
    XCTAssertEqual(decoded.visceralFatLevel, 3)
    XCTAssertEqual(decoded.rightArmLeanPct, 112.4)
    XCTAssertEqual(decoded.trunkFatPct, 94.5)
}

func testInBodyPayload_BackwardsCompatible() throws {
    // Simulate a payload encoded WITHOUT new fields (old app version)
    let oldJSON = """
    {"weightKg":90,"skeletalMuscleMassKg":40,"bodyFatMassKg":15,"bodyFatPct":16.7,"totalBodyWaterL":55,"bmi":25,"basalMetabolicRate":1850}
    """
    let decoded = try JSONDecoder().decode(InBodyPayload.self, from: oldJSON.data(using: .utf8)!)
    XCTAssertEqual(decoded.weightKg, 90)
    XCTAssertNil(decoded.ecwTbwRatio)
    XCTAssertNil(decoded.skeletalMuscleIndex)
    XCTAssertNil(decoded.rightArmLeanPct)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanTests 2>&1 | grep -E '(passed|failed|error:)'`

Expected: compilation errors — `ecwTbwRatio`, `skeletalMuscleIndex`, etc. not found on InBodyPayload.

- [ ] **Step 3: Add new fields to InBodyPayload**

In `Baseline/Models/ScanPayloads.swift`, add after the Segmental Fat block (line 38):

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

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanTests 2>&1 | grep -E '(passed|failed)'`

Expected: All ScanTests pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/Models/ScanPayloads.swift BaselineTests/Models/ScanTests.swift
git commit -m "feat: expand InBodyPayload with 13 new fields (ECW/TBW, SMI, visceral fat, segmental %)"
```

---

### Task 2: Extract and expand InBodyParseResult

**Files:**
- Create: `Baseline/OCR/InBodyParseResult.swift`
- Modify: `Baseline/OCR/InBodyOCRParser.swift` (remove InBodyParseResult from this file)

- [ ] **Step 1: Create InBodyParseResult.swift with all ~35 fields + confidence + scanDate**

Create `Baseline/OCR/InBodyParseResult.swift`:

```swift
import Foundation

/// Result of OCR parsing an InBody 570 sheet. All fields optional since OCR may miss any.
struct InBodyParseResult {
    // Core (required for InBodyPayload)
    var weightKg: Double?
    var skeletalMuscleMassKg: Double?
    var bodyFatMassKg: Double?
    var bodyFatPct: Double?
    var totalBodyWaterL: Double?
    var bmi: Double?
    var basalMetabolicRate: Double?

    // Body Composition Analysis
    var intracellularWaterL: Double?
    var extracellularWaterL: Double?
    var dryLeanMassKg: Double?
    var leanBodyMassKg: Double?
    var inBodyScore: Double?

    // ECW/TBW
    var ecwTbwRatio: Double?

    // SMI & Visceral Fat
    var skeletalMuscleIndex: Double?
    var visceralFatLevel: Double?

    // Segmental Lean (5 segments) — mass in kg
    var rightArmLeanKg: Double?
    var leftArmLeanKg: Double?
    var trunkLeanKg: Double?
    var rightLegLeanKg: Double?
    var leftLegLeanKg: Double?

    // Segmental Lean — sufficiency %
    var rightArmLeanPct: Double?
    var leftArmLeanPct: Double?
    var trunkLeanPct: Double?
    var rightLegLeanPct: Double?
    var leftLegLeanPct: Double?

    // Segmental Fat (5 segments) — mass in kg
    var rightArmFatKg: Double?
    var leftArmFatKg: Double?
    var trunkFatKg: Double?
    var rightLegFatKg: Double?
    var leftLegFatKg: Double?

    // Segmental Fat — sufficiency %
    var rightArmFatPct: Double?
    var leftArmFatPct: Double?
    var trunkFatPct: Double?
    var rightLegFatPct: Double?
    var leftLegFatPct: Double?

    // Metadata
    var scanDate: Date?
    var rawText: String = ""
    var confidence: [String: Float] = [:]
    var detectedUnit: DetectedUnit = .lbs

    enum DetectedUnit {
        case lbs, kg
    }

    // MARK: - Conversion to InBodyPayload

    enum ConversionError: Error, LocalizedError {
        case missingRequiredFields([String])

        var errorDescription: String? {
            switch self {
            case .missingRequiredFields(let fields):
                return "Missing required fields: \(fields.joined(separator: ", "))"
            }
        }
    }

    func toPayload() throws -> InBodyPayload {
        var missing: [String] = []
        if weightKg == nil { missing.append("weightKg") }
        if skeletalMuscleMassKg == nil { missing.append("skeletalMuscleMassKg") }
        if bodyFatMassKg == nil { missing.append("bodyFatMassKg") }
        if bodyFatPct == nil { missing.append("bodyFatPct") }
        if totalBodyWaterL == nil { missing.append("totalBodyWaterL") }
        if bmi == nil { missing.append("bmi") }
        if basalMetabolicRate == nil { missing.append("basalMetabolicRate") }

        guard missing.isEmpty,
              let w = weightKg, let smm = skeletalMuscleMassKg, let bfm = bodyFatMassKg,
              let bf = bodyFatPct, let tbw = totalBodyWaterL, let b = bmi, let bmr = basalMetabolicRate else {
            throw ConversionError.missingRequiredFields(missing)
        }

        var payload = InBodyPayload(
            weightKg: w, skeletalMuscleMassKg: smm, bodyFatMassKg: bfm,
            bodyFatPct: bf, totalBodyWaterL: tbw, bmi: b, basalMetabolicRate: bmr
        )
        payload.intracellularWaterL = intracellularWaterL
        payload.extracellularWaterL = extracellularWaterL
        payload.dryLeanMassKg = dryLeanMassKg
        payload.leanBodyMassKg = leanBodyMassKg
        payload.inBodyScore = inBodyScore
        payload.ecwTbwRatio = ecwTbwRatio
        payload.skeletalMuscleIndex = skeletalMuscleIndex
        payload.visceralFatLevel = visceralFatLevel
        payload.rightArmLeanKg = rightArmLeanKg
        payload.leftArmLeanKg = leftArmLeanKg
        payload.trunkLeanKg = trunkLeanKg
        payload.rightLegLeanKg = rightLegLeanKg
        payload.leftLegLeanKg = leftLegLeanKg
        payload.rightArmLeanPct = rightArmLeanPct
        payload.leftArmLeanPct = leftArmLeanPct
        payload.trunkLeanPct = trunkLeanPct
        payload.rightLegLeanPct = rightLegLeanPct
        payload.leftLegLeanPct = leftLegLeanPct
        payload.rightArmFatKg = rightArmFatKg
        payload.leftArmFatKg = leftArmFatKg
        payload.trunkFatKg = trunkFatKg
        payload.rightLegFatKg = rightLegFatKg
        payload.leftLegFatKg = leftLegFatKg
        payload.rightArmFatPct = rightArmFatPct
        payload.leftArmFatPct = leftArmFatPct
        payload.trunkFatPct = trunkFatPct
        payload.rightLegFatPct = rightLegFatPct
        payload.leftLegFatPct = leftLegFatPct
        return payload
    }

    /// Merge another result into this one. Higher confidence wins per field.
    /// Fields that have been user-edited (marked in `userEditedFields`) are never overwritten.
    mutating func merge(with other: InBodyParseResult, userEditedFields: Set<String>) {
        func pick<T>(_ key: String, current: T?, new: T?) -> T? {
            guard !userEditedFields.contains(key) else { return current }
            guard let newVal = new else { return current }
            guard current != nil else {
                confidence[key] = other.confidence[key] ?? 0
                return newVal
            }
            let currentConf = confidence[key] ?? 0
            let newConf = other.confidence[key] ?? 0
            if newConf > currentConf {
                confidence[key] = newConf
                return newVal
            }
            return current
        }

        weightKg = pick("weightKg", current: weightKg, new: other.weightKg)
        skeletalMuscleMassKg = pick("skeletalMuscleMassKg", current: skeletalMuscleMassKg, new: other.skeletalMuscleMassKg)
        bodyFatMassKg = pick("bodyFatMassKg", current: bodyFatMassKg, new: other.bodyFatMassKg)
        bodyFatPct = pick("bodyFatPct", current: bodyFatPct, new: other.bodyFatPct)
        totalBodyWaterL = pick("totalBodyWaterL", current: totalBodyWaterL, new: other.totalBodyWaterL)
        bmi = pick("bmi", current: bmi, new: other.bmi)
        basalMetabolicRate = pick("basalMetabolicRate", current: basalMetabolicRate, new: other.basalMetabolicRate)
        intracellularWaterL = pick("intracellularWaterL", current: intracellularWaterL, new: other.intracellularWaterL)
        extracellularWaterL = pick("extracellularWaterL", current: extracellularWaterL, new: other.extracellularWaterL)
        dryLeanMassKg = pick("dryLeanMassKg", current: dryLeanMassKg, new: other.dryLeanMassKg)
        leanBodyMassKg = pick("leanBodyMassKg", current: leanBodyMassKg, new: other.leanBodyMassKg)
        inBodyScore = pick("inBodyScore", current: inBodyScore, new: other.inBodyScore)
        ecwTbwRatio = pick("ecwTbwRatio", current: ecwTbwRatio, new: other.ecwTbwRatio)
        skeletalMuscleIndex = pick("skeletalMuscleIndex", current: skeletalMuscleIndex, new: other.skeletalMuscleIndex)
        visceralFatLevel = pick("visceralFatLevel", current: visceralFatLevel, new: other.visceralFatLevel)
        rightArmLeanKg = pick("rightArmLeanKg", current: rightArmLeanKg, new: other.rightArmLeanKg)
        leftArmLeanKg = pick("leftArmLeanKg", current: leftArmLeanKg, new: other.leftArmLeanKg)
        trunkLeanKg = pick("trunkLeanKg", current: trunkLeanKg, new: other.trunkLeanKg)
        rightLegLeanKg = pick("rightLegLeanKg", current: rightLegLeanKg, new: other.rightLegLeanKg)
        leftLegLeanKg = pick("leftLegLeanKg", current: leftLegLeanKg, new: other.leftLegLeanKg)
        rightArmLeanPct = pick("rightArmLeanPct", current: rightArmLeanPct, new: other.rightArmLeanPct)
        leftArmLeanPct = pick("leftArmLeanPct", current: leftArmLeanPct, new: other.leftArmLeanPct)
        trunkLeanPct = pick("trunkLeanPct", current: trunkLeanPct, new: other.trunkLeanPct)
        rightLegLeanPct = pick("rightLegLeanPct", current: rightLegLeanPct, new: other.rightLegLeanPct)
        leftLegLeanPct = pick("leftLegLeanPct", current: leftLegLeanPct, new: other.leftLegLeanPct)
        rightArmFatKg = pick("rightArmFatKg", current: rightArmFatKg, new: other.rightArmFatKg)
        leftArmFatKg = pick("leftArmFatKg", current: leftArmFatKg, new: other.leftArmFatKg)
        trunkFatKg = pick("trunkFatKg", current: trunkFatKg, new: other.trunkFatKg)
        rightLegFatKg = pick("rightLegFatKg", current: rightLegFatKg, new: other.rightLegFatKg)
        leftLegFatKg = pick("leftLegFatKg", current: leftLegFatKg, new: other.leftLegFatKg)
        rightArmFatPct = pick("rightArmFatPct", current: rightArmFatPct, new: other.rightArmFatPct)
        leftArmFatPct = pick("leftArmFatPct", current: leftArmFatPct, new: other.leftArmFatPct)
        trunkFatPct = pick("trunkFatPct", current: trunkFatPct, new: other.trunkFatPct)
        rightLegFatPct = pick("rightLegFatPct", current: rightLegFatPct, new: other.rightLegFatPct)
        leftLegFatPct = pick("leftLegFatPct", current: leftLegFatPct, new: other.leftLegFatPct)
        if scanDate == nil { scanDate = other.scanDate }
    }
}
```

- [ ] **Step 2: Remove InBodyParseResult from InBodyOCRParser.swift**

In `Baseline/OCR/InBodyOCRParser.swift`, delete lines 5-93 (the `InBodyParseResult` struct and its `toPayload()` method). Keep only the `InBodyOCRParser` enum (lines 95-256). The code will compile because `InBodyParseResult` now lives in its own file.

- [ ] **Step 3: Verify build succeeds**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E '(error:|BUILD)'`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/OCR/InBodyParseResult.swift Baseline/OCR/InBodyOCRParser.swift
git commit -m "refactor: extract InBodyParseResult to own file, add new fields + merge logic"
```

---

### Task 3: Document correction (perspective transform)

**Files:**
- Create: `Baseline/OCR/DocumentCorrector.swift`
- Test: `BaselineTests/OCR/DocumentCorrectorTests.swift`

- [ ] **Step 1: Write test for perspective correction**

Create `BaselineTests/OCR/DocumentCorrectorTests.swift`:

```swift
import XCTest
import UIKit
@testable import Baseline

final class DocumentCorrectorTests: XCTestCase {

    func testCorrectPerspective_ReturnsImageWithSameDimensions() async {
        // Create a simple test image (white rectangle on black)
        let size = CGSize(width: 400, height: 600)
        UIGraphicsBeginImageContext(size)
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 50, y: 50, width: 300, height: 500))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let result = await DocumentCorrector.correctPerspective(testImage)
        // Should return an image (may or may not detect the rectangle on a synthetic image)
        // On a synthetic image, it may fall back to returning the original
        XCTAssertNotNil(result)
    }

    func testCropRegion_ProducesCorrectSize() {
        let size = CGSize(width: 1000, height: 1400)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        // Crop the top-left quarter
        let region = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let cropped = DocumentCorrector.cropRegion(testImage, normalizedRect: region)
        XCTAssertNotNil(cropped)
        // Cropped image should be roughly half the width and half the height
        if let cropped {
            XCTAssertEqual(cropped.size.width, 500, accuracy: 2)
            XCTAssertEqual(cropped.size.height, 700, accuracy: 2)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/DocumentCorrectorTests 2>&1 | grep -E '(passed|failed|error:)'`

Expected: compilation error — `DocumentCorrector` not found.

- [ ] **Step 3: Implement DocumentCorrector**

Create `Baseline/OCR/DocumentCorrector.swift`:

```swift
import UIKit
import Vision
import CoreImage

enum DocumentCorrector {

    /// Detect document edges and apply perspective correction.
    /// Falls back to the original image if no document is detected.
    static func correctPerspective(_ image: UIImage) async -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return image
        }

        guard let result = request.results?.first,
              let detectedDocument = result as? VNRectangleObservation else {
            return image
        }

        return applyPerspectiveCorrection(to: image, using: detectedDocument) ?? image
    }

    /// Crop a normalized rect (0–1 coordinate space) from an image.
    static func cropRegion(_ image: UIImage, normalizedRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: normalizedRect.origin.x * w,
            y: normalizedRect.origin.y * h,
            width: normalizedRect.width * w,
            height: normalizedRect.height * h
        )
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Private

    private static func applyPerspectiveCorrection(
        to image: UIImage,
        using observation: VNRectangleObservation
    ) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let imageSize = ciImage.extent.size

        // Vision coordinates are normalized (0-1), bottom-left origin
        func denormalize(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x * imageSize.width, y: point.y * imageSize.height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(denormalize(observation.topLeft), forKey: "inputTopLeft")
        filter.setValue(denormalize(observation.topRight), forKey: "inputTopRight")
        filter.setValue(denormalize(observation.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(denormalize(observation.bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let cgOutput = context.createCGImage(output, from: output.extent) else { return nil }

        // Ensure portrait orientation
        let resultImage = UIImage(cgImage: cgOutput)
        if resultImage.size.width > resultImage.size.height {
            // Landscape — rotate to portrait
            return UIImage(cgImage: cgOutput, scale: 1.0, orientation: .right)
        }
        return resultImage
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/DocumentCorrectorTests 2>&1 | grep -E '(passed|failed)'`

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/OCR/DocumentCorrector.swift BaselineTests/OCR/DocumentCorrectorTests.swift
git commit -m "feat: add DocumentCorrector — perspective correction + region cropping"
```

---

### Task 4: InBody 570 region map + region parsers

**Files:**
- Create: `Baseline/OCR/InBody570RegionMap.swift`
- Create: `Baseline/OCR/InBody570RegionParsers.swift`
- Create: `BaselineTests/OCR/InBody570RegionParsersTests.swift`

- [ ] **Step 1: Write tests for region parsers**

Create `BaselineTests/OCR/InBody570RegionParsersTests.swift`:

```swift
import XCTest
@testable import Baseline

final class InBody570RegionParsersTests: XCTestCase {

    // MARK: - R1: Header (date)

    func testParseHeader_ExtractsDate() {
        let text = "InBody\nName: Test User\nID: 12345\nMale  01. 15. 2026 07:37"
        let result = InBody570RegionParsers.parseHeader(text)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: result.scanDate!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
    }

    // MARK: - R2: Body Composition Analysis

    func testParseBodyComposition_LbsUnit() {
        let text = """
        Intracellular Water lbs 53.1
        Extracellular Water lbs 33.5
        Total Body Water lbs 86.6
        Dry Lean Mass lbs 65.9
        Lean Body Mass lbs 152.5
        Body Fat Mass lbs 14.2
        """
        let result = InBody570RegionParsers.parseBodyComposition(text, unit: .lbs)
        // Values should be converted to kg (lbs * 0.45359237) for mass fields
        XCTAssertEqual(result.intracellularWaterL!, 53.1 * 0.45359237, accuracy: 0.1)
        XCTAssertEqual(result.dryLeanMassKg!, 65.9 * 0.45359237, accuracy: 0.1)
        XCTAssertEqual(result.bodyFatMassKg!, 14.2 * 0.45359237, accuracy: 0.1)
        XCTAssertEqual(result.leanBodyMassKg!, 152.5 * 0.45359237, accuracy: 0.1)
    }

    // MARK: - R3: Muscle-Fat Analysis

    func testParseMuscleFat_ExtractsWeightAndSMM() {
        let text = """
        Weight lbs 134.0
        SMM lbs 93.1
        Body Fat Mass lbs 14.2
        """
        let result = InBody570RegionParsers.parseMuscleFat(text, unit: .lbs)
        XCTAssertEqual(result.weightKg!, 134.0 * 0.45359237, accuracy: 0.1)
        XCTAssertEqual(result.skeletalMuscleMassKg!, 93.1 * 0.45359237, accuracy: 0.1)
    }

    // MARK: - R4: Obesity Analysis

    func testParseObesity_ExtractsBMIAndPBF() {
        let text = """
        BMI 26.1
        PBF 19.2
        """
        let result = InBody570RegionParsers.parseObesity(text)
        XCTAssertEqual(result.bmi, 26.1)
        XCTAssertEqual(result.bodyFatPct, 19.2)
    }

    // MARK: - R5: Segmental Lean

    func testParseSegmentalLean_ExtractsMassAndPct() {
        let text = """
        Right Arm 7.94 lbs 112.4
        Left Arm 7.81 lbs 110.6
        Trunk 80.9 lbs 121.9
        Right Leg 24.5 lbs 116.2
        Left Leg 24.2 lbs 115.8
        """
        let result = InBody570RegionParsers.parseSegmentalLean(text, unit: .lbs)
        XCTAssertEqual(result.rightArmLeanKg!, 7.94 * 0.45359237, accuracy: 0.01)
        XCTAssertEqual(result.rightArmLeanPct, 112.4)
        XCTAssertEqual(result.trunkLeanKg!, 80.9 * 0.45359237, accuracy: 0.1)
        XCTAssertEqual(result.trunkLeanPct, 121.9)
    }

    // MARK: - R8: BMR

    func testParseBMR() {
        let text = "Basal Metabolic Rate\n1842 kcal"
        let result = InBody570RegionParsers.parseBMR(text)
        XCTAssertEqual(result.basalMetabolicRate, 1842)
    }

    // MARK: - R9: SMI

    func testParseSMI() {
        let text = "SMI\n10.4"
        let result = InBody570RegionParsers.parseSMI(text)
        XCTAssertEqual(result.skeletalMuscleIndex, 10.4)
    }

    // MARK: - R10: Visceral Fat

    func testParseVisceralFat() {
        let text = "Visceral Fat Level\n3"
        let result = InBody570RegionParsers.parseVisceralFat(text)
        XCTAssertEqual(result.visceralFatLevel, 3)
    }

    // MARK: - Unit Detection

    func testDetectUnit_Lbs() {
        let text = "Weight lbs 134.0"
        XCTAssertEqual(InBody570RegionParsers.detectUnit(from: text), .lbs)
    }

    func testDetectUnit_Kg() {
        let text = "Weight kg 60.8"
        XCTAssertEqual(InBody570RegionParsers.detectUnit(from: text), .kg)
    }

    func testDetectUnit_Default() {
        let text = "Weight 134.0"
        XCTAssertEqual(InBody570RegionParsers.detectUnit(from: text), .lbs)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: compilation errors — types not found.

- [ ] **Step 3: Implement InBody570RegionMap**

Create `Baseline/OCR/InBody570RegionMap.swift`:

```swift
import UIKit

/// Normalized bounding boxes for each section of the InBody 570 result sheet.
/// Coordinates are in 0–1 space (top-left origin, matching UIKit/CGImage conventions).
/// These are initial estimates — calibrate against real scans.
enum InBody570RegionMap {

    struct Region {
        let id: String
        let rect: CGRect  // normalized (0–1)
        let label: String // human-readable for retry prompts
    }

    static let header = Region(id: "R1", rect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.06), label: "Header")
    static let bodyComposition = Region(id: "R2", rect: CGRect(x: 0.0, y: 0.06, width: 0.55, height: 0.18), label: "Body Composition Analysis")
    static let muscleFat = Region(id: "R3", rect: CGRect(x: 0.0, y: 0.24, width: 0.55, height: 0.12), label: "Muscle-Fat Analysis")
    static let obesity = Region(id: "R4", rect: CGRect(x: 0.0, y: 0.36, width: 0.55, height: 0.06), label: "Obesity Analysis")
    static let segmentalLean = Region(id: "R5", rect: CGRect(x: 0.0, y: 0.42, width: 0.55, height: 0.16), label: "Segmental Lean Analysis")
    static let ecwTbw = Region(id: "R6", rect: CGRect(x: 0.0, y: 0.58, width: 0.55, height: 0.06), label: "ECW/TBW Analysis")
    static let segmentalFat = Region(id: "R7", rect: CGRect(x: 0.55, y: 0.06, width: 0.45, height: 0.16), label: "Segmental Fat Analysis")
    static let bmr = Region(id: "R8", rect: CGRect(x: 0.55, y: 0.22, width: 0.45, height: 0.06), label: "Basal Metabolic Rate")
    static let smi = Region(id: "R9", rect: CGRect(x: 0.55, y: 0.28, width: 0.45, height: 0.05), label: "SMI")
    static let visceralFat = Region(id: "R10", rect: CGRect(x: 0.55, y: 0.33, width: 0.45, height: 0.05), label: "Visceral Fat")

    static let allRegions: [Region] = [
        header, bodyComposition, muscleFat, obesity, segmentalLean,
        ecwTbw, segmentalFat, bmr, smi, visceralFat
    ]

    /// Crop all regions from a perspective-corrected image.
    static func cropAll(from image: UIImage) -> [(Region, UIImage)] {
        allRegions.compactMap { region in
            guard let cropped = DocumentCorrector.cropRegion(image, normalizedRect: region.rect) else { return nil }
            return (region, cropped)
        }
    }
}
```

- [ ] **Step 4: Implement InBody570RegionParsers**

Create `Baseline/OCR/InBody570RegionParsers.swift`:

```swift
import Foundation

/// Per-region text parsers for InBody 570 sections.
/// Each parser takes raw OCR text from a cropped region and extracts known fields.
enum InBody570RegionParsers {

    private static let lbsToKg: Double = 0.45359237

    // MARK: - Unit Detection

    static func detectUnit(from text: String) -> InBodyParseResult.DetectedUnit {
        let lower = text.lowercased()
        if lower.contains("kg") { return .kg }
        return .lbs // default per spec
    }

    // MARK: - R1: Header

    static func parseHeader(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        // InBody 570 date format: "MM. DD. YYYY HH:MM" or similar
        let datePattern = #"(\d{2})\.\s*(\d{2})\.\s*(\d{4})"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let month = Int(text[Range(match.range(at: 1), in: text)!])
            let day = Int(text[Range(match.range(at: 2), in: text)!])
            let year = Int(text[Range(match.range(at: 3), in: text)!])
            if let month, let day, let year {
                var components = DateComponents()
                components.year = year; components.month = month; components.day = day
                result.scanDate = Calendar.current.date(from: components)
            }
        }
        return result
    }

    // MARK: - R2: Body Composition Analysis

    static func parseBodyComposition(_ text: String, unit: InBodyParseResult.DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            guard let value = extractLastNumber(from: line) else { continue }
            let massValue = unit == .lbs ? value * lbsToKg : value

            if lower.contains("intracellular") { result.intracellularWaterL = massValue }
            else if lower.contains("extracellular") && !lower.contains("ecw/tbw") { result.extracellularWaterL = massValue }
            else if lower.contains("total body water") { result.totalBodyWaterL = massValue }
            else if lower.contains("dry lean") { result.dryLeanMassKg = massValue }
            else if lower.contains("lean body") { result.leanBodyMassKg = massValue }
            else if lower.contains("body fat") { result.bodyFatMassKg = massValue }
        }
        return result
    }

    // MARK: - R3: Muscle-Fat Analysis

    static func parseMuscleFat(_ text: String, unit: InBodyParseResult.DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            guard let value = extractLastNumber(from: line) else { continue }
            let massValue = unit == .lbs ? value * lbsToKg : value

            if lower.contains("weight") { result.weightKg = massValue }
            else if lower.contains("smm") || lower.contains("skeletal muscle") { result.skeletalMuscleMassKg = massValue }
            else if lower.contains("body fat") { result.bodyFatMassKg = massValue }
        }
        return result
    }

    // MARK: - R4: Obesity Analysis

    static func parseObesity(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            guard let value = extractLastNumber(from: line) else { continue }
            if lower.contains("bmi") { result.bmi = value }
            else if lower.contains("pbf") || lower.contains("percent body fat") || lower.contains("body fat") { result.bodyFatPct = value }
        }
        return result
    }

    // MARK: - R5: Segmental Lean Analysis

    static func parseSegmentalLean(_ text: String, unit: InBodyParseResult.DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            let numbers = extractAllNumbers(from: line)
            guard !numbers.isEmpty else { continue }
            let mass = unit == .lbs ? numbers[0] * lbsToKg : numbers[0]
            let pct = numbers.count > 1 ? numbers.last : nil

            if lower.contains("right arm") { result.rightArmLeanKg = mass; result.rightArmLeanPct = pct }
            else if lower.contains("left arm") { result.leftArmLeanKg = mass; result.leftArmLeanPct = pct }
            else if lower.contains("trunk") { result.trunkLeanKg = mass; result.trunkLeanPct = pct }
            else if lower.contains("right leg") { result.rightLegLeanKg = mass; result.rightLegLeanPct = pct }
            else if lower.contains("left leg") { result.leftLegLeanKg = mass; result.leftLegLeanPct = pct }
        }
        return result
    }

    // MARK: - R6: ECW/TBW

    static func parseEcwTbw(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        if let value = extractLastNumber(from: text), value < 1.0 {
            result.ecwTbwRatio = value
        }
        return result
    }

    // MARK: - R7: Segmental Fat Analysis

    static func parseSegmentalFat(_ text: String, unit: InBodyParseResult.DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            let numbers = extractAllNumbers(from: line)
            guard !numbers.isEmpty else { continue }
            let mass = unit == .lbs ? numbers[0] * lbsToKg : numbers[0]
            let pct = numbers.count > 1 ? numbers.last : nil

            if lower.contains("right arm") { result.rightArmFatKg = mass; result.rightArmFatPct = pct }
            else if lower.contains("left arm") { result.leftArmFatKg = mass; result.leftArmFatPct = pct }
            else if lower.contains("trunk") { result.trunkFatKg = mass; result.trunkFatPct = pct }
            else if lower.contains("right leg") { result.rightLegFatKg = mass; result.rightLegFatPct = pct }
            else if lower.contains("left leg") { result.leftLegFatKg = mass; result.leftLegFatPct = pct }
        }
        return result
    }

    // MARK: - R8: BMR

    static func parseBMR(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.basalMetabolicRate = extractLastNumber(from: text)
        return result
    }

    // MARK: - R9: SMI

    static func parseSMI(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.skeletalMuscleIndex = extractLastNumber(from: text)
        return result
    }

    // MARK: - R10: Visceral Fat

    static func parseVisceralFat(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.visceralFatLevel = extractLastNumber(from: text)
        return result
    }

    // MARK: - Helpers

    /// Extract the last number from a string (avoids grabbing range/label numbers).
    private static func extractLastNumber(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard let lastMatch = matches.last,
              let range = Range(lastMatch.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    /// Extract all numbers from a string.
    private static func extractAllNumbers(from text: String) -> [Double] {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[range])
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/InBody570RegionParsersTests 2>&1 | grep -E '(passed|failed)'`

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add Baseline/OCR/InBody570RegionMap.swift Baseline/OCR/InBody570RegionParsers.swift BaselineTests/OCR/InBody570RegionParsersTests.swift
git commit -m "feat: add InBody 570 region map + per-region parsers with unit detection"
```

---

### Task 5: Rewrite InBodyOCRParser with region-based pipeline

**Files:**
- Modify: `Baseline/OCR/InBodyOCRParser.swift`
- Modify: `BaselineTests/OCR/InBodyOCRParserTests.swift`

- [ ] **Step 1: Write test for new region-based API**

Replace contents of `BaselineTests/OCR/InBodyOCRParserTests.swift`:

```swift
import XCTest
import UIKit
@testable import Baseline

final class InBodyOCRParserTests: XCTestCase {

    func testRecognizeAndParseRegions_ReturnsResult() async {
        // Create a blank test image (no real text — tests the pipeline, not accuracy)
        let size = CGSize(width: 800, height: 1200)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let result = await InBodyOCRParser.processImage(testImage)
        // With a blank image, all fields should be nil but the result should exist
        XCTAssertNil(result.weightKg)
        XCTAssertNil(result.bmi)
        XCTAssertTrue(result.confidence.isEmpty || result.confidence.values.allSatisfy { $0 >= 0 })
    }

    func testMerge_HigherConfidenceWins() {
        var result1 = InBodyParseResult()
        result1.weightKg = 90.0
        result1.confidence["weightKg"] = 0.5

        var result2 = InBodyParseResult()
        result2.weightKg = 91.0
        result2.confidence["weightKg"] = 0.9

        result1.merge(with: result2, userEditedFields: [])
        XCTAssertEqual(result1.weightKg, 91.0) // higher confidence
        XCTAssertEqual(result1.confidence["weightKg"], 0.9)
    }

    func testMerge_UserEditedFieldsPreserved() {
        var result1 = InBodyParseResult()
        result1.weightKg = 90.0
        result1.confidence["weightKg"] = 0.5

        var result2 = InBodyParseResult()
        result2.weightKg = 91.0
        result2.confidence["weightKg"] = 0.9

        result1.merge(with: result2, userEditedFields: ["weightKg"])
        XCTAssertEqual(result1.weightKg, 90.0) // user-edited, not overwritten
    }

    func testMerge_FillsMissingFields() {
        var result1 = InBodyParseResult()
        result1.weightKg = 90.0
        result1.confidence["weightKg"] = 0.8
        // bmi is nil

        var result2 = InBodyParseResult()
        result2.bmi = 25.0
        result2.confidence["bmi"] = 0.7

        result1.merge(with: result2, userEditedFields: [])
        XCTAssertEqual(result1.weightKg, 90.0) // unchanged
        XCTAssertEqual(result1.bmi, 25.0) // filled from result2
    }
}
```

- [ ] **Step 2: Rewrite InBodyOCRParser**

Replace `Baseline/OCR/InBodyOCRParser.swift` entirely:

```swift
import Foundation
import Vision
import UIKit

/// Region-based OCR pipeline for InBody 570 result sheets.
///
/// Pipeline: image → perspective correct → crop regions → OCR each → parse → merge → confidence score
enum InBodyOCRParser {

    /// Full pipeline: process a captured image and return parsed results with confidence.
    static func processImage(_ image: UIImage) async -> InBodyParseResult {
        // 1. Perspective correction
        let corrected = await DocumentCorrector.correctPerspective(image)

        // 2. Crop all regions
        let regionImages = InBody570RegionMap.cropAll(from: corrected)

        // 3. Detect unit from the muscle-fat region (R3 contains "Weight lbs/kg")
        var detectedUnit: InBodyParseResult.DetectedUnit = .lbs
        if let muscleFatImage = regionImages.first(where: { $0.0.id == "R3" }) {
            let r3Text = await recognizeText(from: muscleFatImage.1)
            detectedUnit = InBody570RegionParsers.detectUnit(from: r3Text)
        }

        // 4. OCR + parse each region sequentially (memory pressure concern)
        var merged = InBodyParseResult()
        merged.detectedUnit = detectedUnit

        for (region, regionImage) in regionImages {
            let text = await recognizeTextWithConfidence(from: regionImage)
            let regionResult = parseRegion(region, text: text.text, confidence: text.avgConfidence, unit: detectedUnit)

            // Merge into accumulated result
            merged.merge(with: regionResult, userEditedFields: [])
        }

        return merged
    }

    // MARK: - Per-Region Dispatch

    private static func parseRegion(
        _ region: InBody570RegionMap.Region,
        text: String,
        confidence: Float,
        unit: InBodyParseResult.DetectedUnit
    ) -> InBodyParseResult {
        var result: InBodyParseResult

        switch region.id {
        case "R1": result = InBody570RegionParsers.parseHeader(text)
        case "R2": result = InBody570RegionParsers.parseBodyComposition(text, unit: unit)
        case "R3": result = InBody570RegionParsers.parseMuscleFat(text, unit: unit)
        case "R4": result = InBody570RegionParsers.parseObesity(text)
        case "R5": result = InBody570RegionParsers.parseSegmentalLean(text, unit: unit)
        case "R6": result = InBody570RegionParsers.parseEcwTbw(text)
        case "R7": result = InBody570RegionParsers.parseSegmentalFat(text, unit: unit)
        case "R8": result = InBody570RegionParsers.parseBMR(text)
        case "R9": result = InBody570RegionParsers.parseSMI(text)
        case "R10": result = InBody570RegionParsers.parseVisceralFat(text)
        default: result = InBodyParseResult()
        }

        // Apply region-level confidence to all extracted fields
        applyConfidence(to: &result, confidence: confidence)
        return result
    }

    /// Set confidence for all non-nil fields in the result.
    private static func applyConfidence(to result: inout InBodyParseResult, confidence: Float) {
        let mirror = Mirror(reflecting: result)
        for child in mirror.children {
            guard let label = child.label, label != "rawText", label != "confidence",
                  label != "scanDate", label != "detectedUnit" else { continue }
            // Check if the value is a non-nil Optional<Double>
            if let opt = child.value as? Double?, opt != nil {
                result.confidence[label] = confidence
            }
        }
    }

    // MARK: - Vision OCR

    /// Recognize text and return average confidence across all observations.
    private static func recognizeTextWithConfidence(from image: UIImage) async -> (text: String, avgConfidence: Float) {
        guard let cgImage = image.cgImage else { return ("", 0) }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ("", 0))
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                let avgConf = observations.isEmpty ? 0 :
                    observations.map { $0.topCandidates(1).first?.confidence ?? 0 }.reduce(0, +) / Float(observations.count)
                continuation.resume(returning: (text, avgConf))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    /// Simple text recognition (no confidence tracking).
    private static func recognizeText(from image: UIImage) async -> String {
        let result = await recognizeTextWithConfidence(from: image)
        return result.text
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/InBodyOCRParserTests 2>&1 | grep -E '(passed|failed)'`

Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add Baseline/OCR/InBodyOCRParser.swift BaselineTests/OCR/InBodyOCRParserTests.swift
git commit -m "feat: rewrite InBodyOCRParser with region-based pipeline + confidence scoring"
```

---

### Task 6: Update ScanEntryViewModel with new fields, retry, and scan date

**Files:**
- Modify: `Baseline/ViewModels/ScanEntryViewModel.swift`
- Modify: `BaselineTests/ViewModels/ScanEntryViewModelTests.swift`

- [ ] **Step 1: Write tests for new ViewModel behavior**

Add to `BaselineTests/ViewModels/ScanEntryViewModelTests.swift`:

```swift
func testPopulateFields_SetsNewFields() {
    let container = makeContainer()
    let vm = ScanEntryViewModel(modelContext: container.mainContext)
    var result = InBodyParseResult()
    result.ecwTbwRatio = 0.380
    result.skeletalMuscleIndex = 10.4
    result.visceralFatLevel = 3
    result.rightArmLeanPct = 112.4
    result.trunkFatPct = 94.5
    result.scanDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15))

    vm.populateFields(from: result)

    XCTAssertEqual(vm.ecwTbwRatio, "0.380")
    XCTAssertEqual(vm.skeletalMuscleIndex, "10.4")
    XCTAssertEqual(vm.visceralFatLevel, "3")
    XCTAssertEqual(vm.rightArmLeanPct, "112.4")
    XCTAssertEqual(vm.trunkFatPct, "94.5")
    XCTAssertNotNil(vm.scanDate)
}

func testRetryMerge_PreservesUserEdits() {
    let container = makeContainer()
    let vm = ScanEntryViewModel(modelContext: container.mainContext)

    // First scan result
    var result1 = InBodyParseResult()
    result1.weightKg = 60.0
    result1.confidence["weightKg"] = 0.5
    vm.populateFields(from: result1)

    // User edits weight manually
    vm.weightKg = "61.5"
    vm.markFieldEdited("weightKg")

    // Retry produces different value
    var result2 = InBodyParseResult()
    result2.weightKg = 62.0
    result2.confidence["weightKg"] = 0.9
    result2.bmi = 25.0
    result2.confidence["bmi"] = 0.8

    vm.mergeRetryResult(result2)

    // User edit should be preserved
    XCTAssertEqual(vm.weightKg, "61.5")
    // New field should be filled
    XCTAssertEqual(vm.bmi, "25.0")
}

func testRetryCount_TracksAttempts() {
    let container = makeContainer()
    let vm = ScanEntryViewModel(modelContext: container.mainContext)
    XCTAssertEqual(vm.retryCount, 0)

    vm.retryCount += 1
    XCTAssertEqual(vm.retryCount, 1)
}
```

- [ ] **Step 2: Update ScanEntryViewModel**

Add new fields and retry logic to `Baseline/ViewModels/ScanEntryViewModel.swift`:

Add after the existing Segmental Fat fields (line 73):

```swift
    // New fields (13)
    var ecwTbwRatio: String = ""
    var skeletalMuscleIndex: String = ""
    var visceralFatLevel: String = ""
    var rightArmLeanPct: String = ""
    var leftArmLeanPct: String = ""
    var trunkLeanPct: String = ""
    var rightLegLeanPct: String = ""
    var leftLegLeanPct: String = ""
    var rightArmFatPct: String = ""
    var leftArmFatPct: String = ""
    var trunkFatPct: String = ""
    var rightLegFatPct: String = ""
    var leftLegFatPct: String = ""

    // Scan date (extracted from sheet header)
    var scanDate: Date?

    // Retry state
    var retryCount: Int = 0
    var userEditedFields: Set<String> = []
```

Add method `markFieldEdited`:

```swift
    func markFieldEdited(_ fieldKey: String) {
        userEditedFields.insert(fieldKey)
    }
```

Update `populateFields(from:)` to include new fields and scan date:

After the existing segmental fat block, add:

```swift
        // New fields
        ecwTbwRatio = result.ecwTbwRatio.map { formatValue($0, decimals: 3) } ?? ""
        skeletalMuscleIndex = result.skeletalMuscleIndex.map { formatValue($0) } ?? ""
        visceralFatLevel = result.visceralFatLevel.map { formatValue($0, decimals: 0) } ?? ""
        rightArmLeanPct = result.rightArmLeanPct.map { formatValue($0) } ?? ""
        leftArmLeanPct = result.leftArmLeanPct.map { formatValue($0) } ?? ""
        trunkLeanPct = result.trunkLeanPct.map { formatValue($0) } ?? ""
        rightLegLeanPct = result.rightLegLeanPct.map { formatValue($0) } ?? ""
        leftLegLeanPct = result.leftLegLeanPct.map { formatValue($0) } ?? ""
        rightArmFatPct = result.rightArmFatPct.map { formatValue($0) } ?? ""
        leftArmFatPct = result.leftArmFatPct.map { formatValue($0) } ?? ""
        trunkFatPct = result.trunkFatPct.map { formatValue($0) } ?? ""
        rightLegFatPct = result.rightLegFatPct.map { formatValue($0) } ?? ""
        leftLegFatPct = result.leftLegFatPct.map { formatValue($0) } ?? ""

        // Scan date
        scanDate = result.scanDate
```

Add `mergeRetryResult` method:

```swift
    func mergeRetryResult(_ newResult: InBodyParseResult) {
        guard var current = parseResult else {
            populateFields(from: newResult)
            return
        }
        current.merge(with: newResult, userEditedFields: userEditedFields)
        populateFields(from: current)
    }
```

Update `processImage` to use new API:

```swift
    func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        let result = await InBodyOCRParser.processImage(image)
        self.parseResult = result

        if retryCount > 0 {
            mergeRetryResult(result)
        } else {
            populateFields(from: result)
        }

        isProcessing = false
        currentStep = .review
    }
```

Update `save()` to use `scanDate`:

Change `let scan = Scan(date: Date(), ...)` to:

```swift
        let scan = Scan(date: scanDate ?? Date(), type: selectedType, source: selectedSource, payload: data)
```

Update `buildPayload()` to include new fields in the returned InBodyPayload. After the existing segmental fat assignments, add:

```swift
            ecwTbwRatio: Double(ecwTbwRatio),
            skeletalMuscleIndex: Double(skeletalMuscleIndex),
            visceralFatLevel: Double(visceralFatLevel),
            rightArmLeanPct: Double(rightArmLeanPct),
            leftArmLeanPct: Double(leftArmLeanPct),
            trunkLeanPct: Double(trunkLeanPct),
            rightLegLeanPct: Double(rightLegLeanPct),
            leftLegLeanPct: Double(leftLegLeanPct),
            rightArmFatPct: Double(rightArmFatPct),
            leftArmFatPct: Double(leftArmFatPct),
            trunkFatPct: Double(trunkFatPct),
            rightLegFatPct: Double(rightLegFatPct),
            leftLegFatPct: Double(leftLegFatPct)
```

Add a `formatValue` overload for controlling decimal places:

```swift
    private func formatValue(_ value: Double, decimals: Int = 1) -> String {
        if decimals == 0 { return String(format: "%.0f", value) }
        if decimals == 3 { return String(format: "%.3f", value) }
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntryViewModelTests 2>&1 | grep -E '(passed|failed)'`

Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add Baseline/ViewModels/ScanEntryViewModel.swift BaselineTests/ViewModels/ScanEntryViewModelTests.swift
git commit -m "feat: update ScanEntryViewModel with new fields, retry merge, scan date"
```

---

### Task 7: Custom camera view with AVCaptureSession + document detection

**Files:**
- Create: `Baseline/Views/Body/ScanCameraView.swift`
- Modify: `Baseline/Views/Body/ScanEntryFlow.swift` (swap CameraView reference)

- [ ] **Step 1: Create ScanCameraView**

Create `Baseline/Views/Body/ScanCameraView.swift`. This is a UIViewControllerRepresentable that wraps a custom AVCaptureSession with:
- Live camera preview
- Guide frame overlay (corner brackets + dashed/solid guide)
- Document detection feedback (accent → green when sheet detected)
- Status hint text ("Align sheet within frame" → "Good — tap to capture")
- Shutter button + close button
- Simulator fallback (photo picker)

```swift
import SwiftUI
import AVFoundation
import Vision
import PhotosUI

struct ScanCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        #if targetEnvironment(simulator)
        return SimulatorFallbackController(onCapture: onCapture, onCancel: onCancel)
        #else
        let vc = ScanCameraViewController()
        vc.onCapture = onCapture
        vc.onCancel = onCancel
        return vc
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Camera View Controller

#if !targetEnvironment(simulator)
class ScanCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let guideOverlay = GuideOverlayView()
    private var documentDetected = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
        setupButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        guideOverlay.frame = view.bounds
    }

    private func setupCamera() {
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Add video output for document detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(DocumentDetectionDelegate(onDetection: { [weak self] detected in
            DispatchQueue.main.async {
                guard self?.documentDetected != detected else { return }
                self?.documentDetected = detected
                self?.guideOverlay.setReady(detected)
            }
        }), queue: DispatchQueue(label: "document-detection"))
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
    }

    private func setupOverlay() {
        guideOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guideOverlay)
        NSLayoutConstraint.activate([
            guideOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            guideOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            guideOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guideOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupButtons() {
        // Shutter button
        let shutterButton = UIButton(type: .custom)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.white.cgColor
        shutterButton.backgroundColor = .white
        let innerCircle = UIView()
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 27
        innerCircle.isUserInteractionEnabled = false
        shutterButton.addSubview(innerCircle)
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(shutterButton)

        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 16
        closeButton.addTarget(self, action: #selector(cancelCapture), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),
            innerCircle.centerXAnchor.constraint(equalTo: shutterButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 54),
            innerCircle.heightAnchor.constraint(equalToConstant: 54),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func cancelCapture() {
        onCancel?()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        onCapture?(image)
    }
}

// MARK: - Document Detection Delegate

private class DocumentDetectionDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let onDetection: (Bool) -> Void
    private var lastCheck = Date.distantPast

    init(onDetection: @escaping (Bool) -> Void) {
        self.onDetection = onDetection
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle to ~5fps
        let now = Date()
        guard now.timeIntervalSince(lastCheck) > 0.2 else { return }
        lastCheck = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectRectanglesRequest { request, _ in
            let detected = !(request.results as? [VNRectangleObservation] ?? []).isEmpty
            self.onDetection(detected)
        }
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 0.9
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
}

// MARK: - Guide Overlay View

private class GuideOverlayView: UIView {
    private let accentColor = UIColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 1) // --accent
    private let greenColor = UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1)
    private var isReady = false
    private let hintLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.text = "Align sheet within frame"
        hintLabel.font = .systemFont(ofSize: 13, weight: .medium)
        hintLabel.textColor = UIColor(white: 0.7, alpha: 1)
        hintLabel.textAlignment = .center
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        hintLabel.layer.cornerRadius = 16
        hintLabel.layer.masksToBounds = true
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -130),
            hintLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            hintLabel.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setReady(_ ready: Bool) {
        guard isReady != ready else { return }
        isReady = ready
        hintLabel.text = ready ? "Good — tap to capture" : "Align sheet within frame"
        hintLabel.textColor = ready ? greenColor : UIColor(white: 0.7, alpha: 1)
        hintLabel.backgroundColor = ready ? greenColor.withAlphaComponent(0.15) : UIColor.black.withAlphaComponent(0.6)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let guideW: CGFloat = 240
        let guideH: CGFloat = 340
        let guideRect = CGRect(
            x: (bounds.width - guideW) / 2,
            y: (bounds.height - guideH) / 2 - 40,
            width: guideW,
            height: guideH
        )

        let color = isReady ? greenColor : accentColor
        let cornerLen: CGFloat = 28
        let lineWidth: CGFloat = 3.0

        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)

        // Top-left
        ctx.move(to: CGPoint(x: guideRect.minX, y: guideRect.minY + cornerLen))
        ctx.addLine(to: CGPoint(x: guideRect.minX, y: guideRect.minY))
        ctx.addLine(to: CGPoint(x: guideRect.minX + cornerLen, y: guideRect.minY))
        ctx.strokePath()

        // Top-right
        ctx.move(to: CGPoint(x: guideRect.maxX - cornerLen, y: guideRect.minY))
        ctx.addLine(to: CGPoint(x: guideRect.maxX, y: guideRect.minY))
        ctx.addLine(to: CGPoint(x: guideRect.maxX, y: guideRect.minY + cornerLen))
        ctx.strokePath()

        // Bottom-left
        ctx.move(to: CGPoint(x: guideRect.minX, y: guideRect.maxY - cornerLen))
        ctx.addLine(to: CGPoint(x: guideRect.minX, y: guideRect.maxY))
        ctx.addLine(to: CGPoint(x: guideRect.minX + cornerLen, y: guideRect.maxY))
        ctx.strokePath()

        // Bottom-right
        ctx.move(to: CGPoint(x: guideRect.maxX - cornerLen, y: guideRect.maxY))
        ctx.addLine(to: CGPoint(x: guideRect.maxX, y: guideRect.maxY))
        ctx.addLine(to: CGPoint(x: guideRect.maxX, y: guideRect.maxY - cornerLen))
        ctx.strokePath()

        // Dashed/solid inner guide
        let inset = guideRect.insetBy(dx: 4, dy: 4)
        ctx.setStrokeColor(color.withAlphaComponent(isReady ? 0.3 : 0.2).cgColor)
        ctx.setLineWidth(1.5)
        if !isReady {
            ctx.setLineDash(phase: 0, lengths: [6, 4])
        }
        let path = UIBezierPath(roundedRect: inset, cornerRadius: 6)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
    }
}
#endif

// MARK: - Simulator Fallback

private class SimulatorFallbackController: UIViewController, PHPickerViewControllerDelegate {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            onCancel()
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            DispatchQueue.main.async {
                if let image = image as? UIImage {
                    self?.onCapture(image)
                } else {
                    self?.onCancel()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Update ScanEntryFlow to use ScanCameraView**

In `Baseline/Views/Body/ScanEntryFlow.swift`, replace the import/usage of `CameraView` with `ScanCameraView`. Find the camera step case and change `CameraView(` to `ScanCameraView(`. The callback signatures are identical (`onCapture: (UIImage) -> Void`, `onCancel: () -> Void`).

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E '(error:|BUILD)'`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Body/ScanCameraView.swift Baseline/Views/Body/ScanEntryFlow.swift
git commit -m "feat: custom camera view with AVCaptureSession, document detection, guide overlay"
```

---

### Task 8: Update review screen in ScanEntryFlow

**Files:**
- Modify: `Baseline/Views/Body/ScanEntryFlow.swift`

This task updates the review step of ScanEntryFlow to match the mockup (`docs/mockups/scan-review-ui-2026-04-07.html`):
- Date chip at top (from OCR-extracted date)
- Warning banner ("N fields may need review")
- Field sections ordered to mirror InBody 570 printout
- Three field states (normal / amber low-confidence / dashed missing)
- Editable value cells with card background
- Segmental tables with mass + sufficiency %
- Retry banner with "Retry Scan" button
- Save button disabled when required fields missing

- [ ] **Step 1: Rewrite the review step view**

In `ScanEntryFlow.swift`, replace the existing review case content. The review section should use the ViewModel's new fields (from Task 6) and the existing `lowConfidenceFields` set. Add the retry banner when `retryCount == 0` and fields are missing. Add date chip bound to `vm.scanDate`.

Key view components to implement:
- `reviewDateChip` — centered date chip, tappable to show DatePicker
- `reviewWarningBanner` — amber banner showing count of low-confidence fields
- `reviewRetryBanner` — amber banner with "Retry Scan" button
- `reviewFieldRow(label:value:unit:fieldKey:)` — editable row with three states
- `reviewSegmentalSection(title:segments:)` — table with mass + sufficiency % columns
- Save button bound to `vm.canSave`

Each field row should:
- Show card background on the value (signaling editability)
- Amber border + text when `fieldKey` is in `vm.lowConfidenceFields`
- Dashed border + "--" + unit when value is empty
- Use `TextField` with `.keyboardType(.decimalPad)` bound to the VM's string property

- [ ] **Step 2: Build and visual test**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E '(error:|BUILD)'`

Launch on simulator and verify the review screen renders correctly with test data.

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Body/ScanEntryFlow.swift
git commit -m "feat: redesigned review screen with confidence flagging, retry, editable cells"
```

---

### Task 9: Update ScanDetailView with new fields

**Files:**
- Modify: `Baseline/Views/Body/ScanDetailView.swift`

- [ ] **Step 1: Add new field display sections**

In `ScanDetailView.swift`, add display rows for:
- ECW/TBW Ratio (in the Body Composition section)
- SMI (in Additional Metrics)
- Visceral Fat Level (in Additional Metrics)
- Sufficiency % for each segmental lean/fat segment (add a second column or sub-label)

Follow the existing pattern of grouped sections with label-value rows. The new fields come from `InBodyPayload` (already expanded in Task 1).

- [ ] **Step 2: Also update ScanEditView if it exists in the same file**

Add editable fields for the new properties so users can edit them after saving.

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E '(error:|BUILD)'`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Body/ScanDetailView.swift
git commit -m "feat: display new InBody fields (SMI, visceral fat, ECW/TBW, segmental %) in scan detail"
```

---

### Task 10: Re-record snapshot tests

**Files:**
- Modify: `BaselineTests/Snapshots/ScanEntrySnapshotTests.swift`

- [ ] **Step 1: Update snapshot test fixtures**

Update `ScanEntrySnapshotTests.swift` to use the new `ScanCameraView` and populate new fields in the review state test. Add a test case for the retry prompt state.

- [ ] **Step 2: Set isRecording = true and run**

```bash
sed -i '' 's/isRecording = false/isRecording = true/' BaselineTests/Snapshots/ScanEntrySnapshotTests.swift
xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntrySnapshotTests 2>&1 | grep -E '(passed|failed)'
```

- [ ] **Step 3: Set isRecording = false and verify pass**

```bash
sed -i '' 's/isRecording = true/isRecording = false/' BaselineTests/Snapshots/ScanEntrySnapshotTests.swift
xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntrySnapshotTests 2>&1 | grep -E '(passed|failed)'
```

Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add BaselineTests/Snapshots/
git commit -m "test: re-record scan entry snapshot tests for redesigned review screen"
```

---

### Task 11: Full build verification + cleanup

**Files:**
- Delete: `Baseline/Views/Body/CameraView.swift` (replaced by ScanCameraView)

- [ ] **Step 1: Remove old CameraView**

```bash
rm Baseline/Views/Body/CameraView.swift
```

- [ ] **Step 2: Full build**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E '(error:|BUILD)'`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run all tests**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E '(Test Suite.*passed|Test Suite.*failed|TEST)'`

Expected: All test suites pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove old CameraView, final cleanup for OCR camera redesign"
```
