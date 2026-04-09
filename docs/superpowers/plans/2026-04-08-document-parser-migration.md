# RecognizeDocumentsRequest Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the regex-based InBody OCR parser with iOS 26's `RecognizeDocumentsRequest` structured table extraction, and replace the custom camera with Apple's `VNDocumentCameraViewController`.

**Architecture:** New `InBodyDocumentParser` uses Vision's `RecognizeDocumentsRequest` to detect tables in the scanned image, walks rows to extract label-value pairs, and maps them to the existing `InBodyParseResult`. `DocumentScannerView` wraps Apple's document camera. Old parser files stay as dead code for potential fallback.

**Tech Stack:** Swift, Vision framework (`RecognizeDocumentsRequest`), VisionKit (`VNDocumentCameraViewController`), SwiftUI, SwiftData

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Baseline/OCR/InBodyDocumentParser.swift` | Create | New extraction engine using RecognizeDocumentsRequest |
| `Baseline/Views/Body/DocumentScannerView.swift` | Create | UIViewControllerRepresentable wrapping VNDocumentCameraViewController |
| `Baseline/ViewModels/ScanEntryViewModel.swift` | Modify | Call new parser instead of old one |
| `Baseline/Views/Body/ScanEntryFlow.swift` | Modify | Swap camera step to use DocumentScannerView |
| `BaselineTests/OCR/InBodyDocumentParserTests.swift` | Create | Tests for label matching and value extraction |
| `Baseline/OCR/InBodyOCRParser.swift` | Keep (dead) | Old regex parser — not called |
| `Baseline/Views/Body/ScanCameraView.swift` | Keep (dead) | Old custom camera — not called |
| `Baseline/OCR/DocumentCorrector.swift` | Keep (dead) | Old perspective correction — not called |
| `Baseline/OCR/InBody570RegionMap.swift` | Keep (dead) | Old region map — not called |
| `Baseline/OCR/InBody570RegionParsers.swift` | Keep (dead) | Old region parsers — not called |

---

### Task 1: Create InBodyDocumentParser with label mapping

**Files:**
- Create: `Baseline/OCR/InBodyDocumentParser.swift`
- Test: `BaselineTests/OCR/InBodyDocumentParserTests.swift`

- [ ] **Step 1: Write the failing test for label-to-key mapping**

Create the test file:

```swift
// BaselineTests/OCR/InBodyDocumentParserTests.swift
import XCTest
@testable import Baseline

final class InBodyDocumentParserTests: XCTestCase {

    // MARK: - Label Matching

    func testExactLabelMatch() {
        let key = InBodyDocumentParser.fieldKey(for: "Weight")
        XCTAssertEqual(key, "weightKg")
    }

    func testLabelMatchIsCaseInsensitive() {
        let key = InBodyDocumentParser.fieldKey(for: "skeletal muscle mass")
        XCTAssertEqual(key, "skeletalMuscleMassKg")
    }

    func testLabelMatchWithTrailingUnits() {
        // OCR may include units in the label cell: "Weight (kg)"
        let key = InBodyDocumentParser.fieldKey(for: "Weight (kg)")
        XCTAssertEqual(key, "weightKg")
    }

    func testUnknownLabelReturnsNil() {
        let key = InBodyDocumentParser.fieldKey(for: "Some Random Text")
        XCTAssertNil(key)
    }

    func testAllCoreLabelsRecognized() {
        let coreLabels = [
            "Weight": "weightKg",
            "Skeletal Muscle Mass": "skeletalMuscleMassKg",
            "Body Fat Mass": "bodyFatMassKg",
            "Percent Body Fat": "bodyFatPct",
            "Total Body Water": "totalBodyWaterL",
            "BMI": "bmi",
            "Basal Metabolic Rate": "basalMetabolicRate",
        ]
        for (label, expectedKey) in coreLabels {
            XCTAssertEqual(
                InBodyDocumentParser.fieldKey(for: label), expectedKey,
                "Failed to match label: \(label)"
            )
        }
    }

    func testOCRVariantLabels() {
        // Common OCR misreads and alternate phrasings on InBody sheets
        let variants: [(String, String)] = [
            ("PBF", "bodyFatPct"),
            ("BMR", "basalMetabolicRate"),
            ("ECW/TBW", "ecwTbwRatio"),
            ("SMI", "skeletalMuscleIndex"),
            ("Visceral Fat Level", "visceralFatLevel"),
            ("InBody Score", "inBodyScore"),
            ("Intracellular Water", "intracellularWaterL"),
            ("Extracellular Water", "extracellularWaterL"),
            ("Dry Lean Mass", "dryLeanMassKg"),
            ("Lean Body Mass", "leanBodyMassKg"),
        ]
        for (label, expectedKey) in variants {
            XCTAssertEqual(
                InBodyDocumentParser.fieldKey(for: label), expectedKey,
                "Failed to match variant label: \(label)"
            )
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/InBodyDocumentParserTests 2>&1 | tail -20`
Expected: FAIL — `InBodyDocumentParser` does not exist yet.

- [ ] **Step 3: Create InBodyDocumentParser with label mapping**

```swift
// Baseline/OCR/InBodyDocumentParser.swift
import Foundation
import UIKit
import Vision

/// Extracts InBody 570 data using iOS 26 RecognizeDocumentsRequest.
///
/// Replaces the regex-based InBodyOCRParser with structured table detection.
/// The old parser remains in the project as inactive fallback.
struct InBodyDocumentParser {

    // MARK: - Public API

    /// Parse an InBody result sheet image into structured data.
    static func parse(image: UIImage) async -> InBodyParseResult {
        guard let cgImage = image.cgImage else {
            return InBodyParseResult()
        }

        var result = InBodyParseResult()

        do {
            let request = RecognizeDocumentsRequest()
            let observations = try await request.perform(on: cgImage)

            guard let doc = observations.first?.document else {
                return result
            }

            // Store observation-level confidence if available
            let observationConfidence = observations.first?.confidence ?? 0

            // 1. Extract from tables (primary path)
            extractFromTables(doc.tables, into: &result, confidence: observationConfidence)

            // 2. Extract from paragraphs (fallback for values not in tables)
            extractFromParagraphs(doc.paragraphs, into: &result, confidence: observationConfidence)

            // 3. Extract scan date from detected data
            extractDate(from: doc, into: &result)

            // 4. Store raw transcript for debugging
            result.rawText = doc.transcript

        } catch {
            #if DEBUG
            print("[InBodyDocumentParser] RecognizeDocumentsRequest failed: \(error)")
            #endif
        }

        return result
    }

    // MARK: - Label-to-Key Mapping

    /// Maps a recognized label string to an InBodyParseResult field key.
    /// Returns nil if the label is not recognized.
    static func fieldKey(for label: String) -> String? {
        let normalized = label
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            // Strip parenthesized units: "Weight (kg)" → "weight"
            .replacingOccurrences(of: #"\s*\(.*?\)\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return labelMap[normalized]
    }

    // MARK: - Label Dictionary

    /// Maps lowercased label text to InBodyParseResult field keys.
    /// Includes exact InBody 570 labels and common OCR variants.
    static let labelMap: [String: String] = [
        // Core fields
        "weight": "weightKg",
        "skeletal muscle mass": "skeletalMuscleMassKg",
        "body fat mass": "bodyFatMassKg",
        "percent body fat": "bodyFatPct",
        "pbf": "bodyFatPct",
        "total body water": "totalBodyWaterL",
        "bmi": "bmi",
        "body mass index": "bmi",
        "basal metabolic rate": "basalMetabolicRate",
        "bmr": "basalMetabolicRate",

        // Body Composition
        "intracellular water": "intracellularWaterL",
        "icw": "intracellularWaterL",
        "extracellular water": "extracellularWaterL",
        "ecw": "extracellularWaterL",
        "dry lean mass": "dryLeanMassKg",
        "lean body mass": "leanBodyMassKg",
        "lbm": "leanBodyMassKg",
        "inbody score": "inBodyScore",

        // Segmental Lean
        "right arm lean": "rightArmLeanKg",
        "left arm lean": "leftArmLeanKg",
        "trunk lean": "trunkLeanKg",
        "right leg lean": "rightLegLeanKg",
        "left leg lean": "leftLegLeanKg",

        // Segmental Fat
        "right arm fat": "rightArmFatKg",
        "left arm fat": "leftArmFatKg",
        "trunk fat": "trunkFatKg",
        "right leg fat": "rightLegFatKg",
        "left leg fat": "leftLegFatKg",

        // ECW/TBW, SMI, Visceral Fat
        "ecw/tbw": "ecwTbwRatio",
        "ecw/tbw ratio": "ecwTbwRatio",
        "smi": "skeletalMuscleIndex",
        "skeletal muscle index": "skeletalMuscleIndex",
        "visceral fat level": "visceralFatLevel",
        "visceral fat area": "visceralFatLevel",
    ]

    // MARK: - Table Extraction

    static func extractFromTables(
        _ tables: [DocumentObservation.Container.Table],
        into result: inout InBodyParseResult,
        confidence: Float
    ) {
        for table in tables {
            for row in table.rows {
                guard let labelCell = row.first else { continue }
                let labelText = labelCell.content.transcript

                guard let key = fieldKey(for: labelText) else { continue }

                // Look for a numeric value in subsequent cells
                for cell in row.dropFirst() {
                    let valueText = cell.content.transcript
                    if let value = parseNumericValue(valueText) {
                        setField(key, value: value, on: &result)
                        if confidence > 0 {
                            result.confidence[key] = confidence
                        }
                        break
                    }
                }
            }
        }
    }

    // MARK: - Paragraph Extraction (fallback)

    static func extractFromParagraphs(
        _ paragraphs: [DocumentObservation.Container.Text],
        into result: inout InBodyParseResult,
        confidence: Float
    ) {
        for paragraph in paragraphs {
            for line in paragraph.lines {
                let text = line.transcript
                // Try "Label: Value" or "Label Value" patterns
                for (label, key) in labelMap {
                    // Skip if already found in table extraction
                    guard getField(key, from: result) == nil else { continue }

                    let pattern = NSRegularExpression.escapedPattern(for: label)
                    let regex = try? NSRegularExpression(
                        pattern: #"\b"# + pattern + #"\b[:\s]+([0-9]+\.?[0-9]*)"#,
                        options: [.caseInsensitive]
                    )
                    if let match = regex?.firstMatch(
                        in: text,
                        range: NSRange(text.startIndex..., in: text)
                    ),
                       let valueRange = Range(match.range(at: 1), in: text),
                       let value = Double(text[valueRange])
                    {
                        setField(key, value: value, on: &result)
                        if confidence > 0 {
                            result.confidence[key] = confidence
                        }
                    }
                }
            }
        }
    }

    // MARK: - Date Extraction

    /// Extracts the scan date from detected data in the document.
    /// Note: The exact `detectedData` enum API should be verified against
    /// Xcode's autocomplete — the case names may differ from documentation.
    static func extractDate(
        from doc: DocumentObservation.Container,
        into result: inout InBodyParseResult
    ) {
        for data in doc.detectedData {
            if case .date(let dateMatch) = data.match.details,
               let date = dateMatch.date {
                result.scanDate = date
                return
            }
        }
    }

    // MARK: - Helpers

    /// Parses a numeric value from text, stripping units and whitespace.
    static func parseNumericValue(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: #"[^\d.\-]"#, with: "", options: .regularExpression)
        return Double(cleaned)
    }

    /// Sets a field on InBodyParseResult by key.
    static func setField(_ key: String, value: Double, on result: inout InBodyParseResult) {
        switch key {
        case "weightKg": result.weightKg = value
        case "skeletalMuscleMassKg": result.skeletalMuscleMassKg = value
        case "bodyFatMassKg": result.bodyFatMassKg = value
        case "bodyFatPct": result.bodyFatPct = value
        case "totalBodyWaterL": result.totalBodyWaterL = value
        case "bmi": result.bmi = value
        case "basalMetabolicRate": result.basalMetabolicRate = value
        case "intracellularWaterL": result.intracellularWaterL = value
        case "extracellularWaterL": result.extracellularWaterL = value
        case "dryLeanMassKg": result.dryLeanMassKg = value
        case "leanBodyMassKg": result.leanBodyMassKg = value
        case "inBodyScore": result.inBodyScore = value
        case "rightArmLeanKg": result.rightArmLeanKg = value
        case "leftArmLeanKg": result.leftArmLeanKg = value
        case "trunkLeanKg": result.trunkLeanKg = value
        case "rightLegLeanKg": result.rightLegLeanKg = value
        case "leftLegLeanKg": result.leftLegLeanKg = value
        case "rightArmFatKg": result.rightArmFatKg = value
        case "leftArmFatKg": result.leftArmFatKg = value
        case "trunkFatKg": result.trunkFatKg = value
        case "rightLegFatKg": result.rightLegFatKg = value
        case "leftLegFatKg": result.leftLegFatKg = value
        case "ecwTbwRatio": result.ecwTbwRatio = value
        case "skeletalMuscleIndex": result.skeletalMuscleIndex = value
        case "visceralFatLevel": result.visceralFatLevel = value
        case "rightArmLeanPct": result.rightArmLeanPct = value
        case "leftArmLeanPct": result.leftArmLeanPct = value
        case "trunkLeanPct": result.trunkLeanPct = value
        case "rightLegLeanPct": result.rightLegLeanPct = value
        case "leftLegLeanPct": result.leftLegLeanPct = value
        case "rightArmFatPct": result.rightArmFatPct = value
        case "leftArmFatPct": result.leftArmFatPct = value
        case "trunkFatPct": result.trunkFatPct = value
        case "rightLegFatPct": result.rightLegFatPct = value
        case "leftLegFatPct": result.leftLegFatPct = value
        default: break
        }
    }

    /// Gets a field value from InBodyParseResult by key. Returns nil if unset.
    static func getField(_ key: String, from result: InBodyParseResult) -> Double? {
        switch key {
        case "weightKg": return result.weightKg
        case "skeletalMuscleMassKg": return result.skeletalMuscleMassKg
        case "bodyFatMassKg": return result.bodyFatMassKg
        case "bodyFatPct": return result.bodyFatPct
        case "totalBodyWaterL": return result.totalBodyWaterL
        case "bmi": return result.bmi
        case "basalMetabolicRate": return result.basalMetabolicRate
        case "intracellularWaterL": return result.intracellularWaterL
        case "extracellularWaterL": return result.extracellularWaterL
        case "dryLeanMassKg": return result.dryLeanMassKg
        case "leanBodyMassKg": return result.leanBodyMassKg
        case "inBodyScore": return result.inBodyScore
        case "rightArmLeanKg": return result.rightArmLeanKg
        case "leftArmLeanKg": return result.leftArmLeanKg
        case "trunkLeanKg": return result.trunkLeanKg
        case "rightLegLeanKg": return result.rightLegLeanKg
        case "leftLegLeanKg": return result.leftLegLeanKg
        case "rightArmFatKg": return result.rightArmFatKg
        case "leftArmFatKg": return result.leftArmFatKg
        case "trunkFatKg": return result.trunkFatKg
        case "rightLegFatKg": return result.rightLegFatKg
        case "leftLegFatKg": return result.leftLegFatKg
        case "ecwTbwRatio": return result.ecwTbwRatio
        case "skeletalMuscleIndex": return result.skeletalMuscleIndex
        case "visceralFatLevel": return result.visceralFatLevel
        case "rightArmLeanPct": return result.rightArmLeanPct
        case "leftArmLeanPct": return result.leftArmLeanPct
        case "trunkLeanPct": return result.trunkLeanPct
        case "rightLegLeanPct": return result.rightLegLeanPct
        case "leftLegLeanPct": return result.leftLegLeanPct
        case "rightArmFatPct": return result.rightArmFatPct
        case "leftArmFatPct": return result.leftArmFatPct
        case "trunkFatPct": return result.trunkFatPct
        case "rightLegFatPct": return result.rightLegFatPct
        case "leftLegFatPct": return result.leftLegFatPct
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/InBodyDocumentParserTests 2>&1 | tail -20`
Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Baseline/OCR/InBodyDocumentParser.swift BaselineTests/OCR/InBodyDocumentParserTests.swift
git commit -m "feat: add InBodyDocumentParser with label-to-key mapping

Uses iOS 26 RecognizeDocumentsRequest for structured table extraction.
Includes label map for all 35 InBody 570 fields with OCR variants."
```

---

### Task 2: Test numeric value parsing

**Files:**
- Modify: `BaselineTests/OCR/InBodyDocumentParserTests.swift`

- [ ] **Step 1: Write the failing tests for parseNumericValue**

Add to `InBodyDocumentParserTests`:

```swift
    // MARK: - Numeric Value Parsing

    func testParseCleanNumber() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("89.5"), 89.5)
    }

    func testParseNumberWithUnits() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("89.5 kg"), 89.5)
    }

    func testParseNumberWithPercent() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("17.1%"), 17.1)
    }

    func testParseInteger() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("1842 kcal"), 1842)
    }

    func testParseRatio() {
        XCTAssertEqual(InBodyDocumentParser.parseNumericValue("0.380"), 0.380)
    }

    func testParseEmptyStringReturnsNil() {
        XCTAssertNil(InBodyDocumentParser.parseNumericValue(""))
    }

    func testParseNonNumericReturnsNil() {
        XCTAssertNil(InBodyDocumentParser.parseNumericValue("Normal"))
    }
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/InBodyDocumentParserTests 2>&1 | tail -20`
Expected: All 14 tests PASS (parseNumericValue is already implemented in Task 1).

- [ ] **Step 3: Commit**

```bash
git add BaselineTests/OCR/InBodyDocumentParserTests.swift
git commit -m "test: add numeric value parsing tests for InBodyDocumentParser"
```

---

### Task 3: Test setField/getField round-trip

**Files:**
- Modify: `BaselineTests/OCR/InBodyDocumentParserTests.swift`

- [ ] **Step 1: Write the tests**

Add to `InBodyDocumentParserTests`:

```swift
    // MARK: - setField / getField Round-Trip

    func testSetAndGetAllCoreFields() {
        var result = InBodyParseResult()

        let fields: [(String, Double)] = [
            ("weightKg", 89.5),
            ("skeletalMuscleMassKg", 40.2),
            ("bodyFatMassKg", 15.3),
            ("bodyFatPct", 17.1),
            ("totalBodyWaterL", 54.0),
            ("bmi", 24.1),
            ("basalMetabolicRate", 1842),
        ]

        for (key, value) in fields {
            InBodyDocumentParser.setField(key, value: value, on: &result)
        }

        for (key, expected) in fields {
            XCTAssertEqual(
                InBodyDocumentParser.getField(key, from: result), expected,
                "Round-trip failed for \(key)"
            )
        }
    }

    func testSetAndGetSegmentalFields() {
        var result = InBodyParseResult()

        InBodyDocumentParser.setField("rightArmLeanKg", value: 3.8, on: &result)
        InBodyDocumentParser.setField("trunkFatPct", value: 94.5, on: &result)
        InBodyDocumentParser.setField("ecwTbwRatio", value: 0.380, on: &result)
        InBodyDocumentParser.setField("visceralFatLevel", value: 3, on: &result)

        XCTAssertEqual(result.rightArmLeanKg, 3.8)
        XCTAssertEqual(result.trunkFatPct, 94.5)
        XCTAssertEqual(result.ecwTbwRatio, 0.380)
        XCTAssertEqual(result.visceralFatLevel, 3)
    }

    func testGetFieldReturnsNilForUnsetField() {
        let result = InBodyParseResult()
        XCTAssertNil(InBodyDocumentParser.getField("weightKg", from: result))
    }

    func testGetFieldReturnsNilForUnknownKey() {
        let result = InBodyParseResult()
        XCTAssertNil(InBodyDocumentParser.getField("nonexistent", from: result))
    }
```

- [ ] **Step 2: Run tests**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/InBodyDocumentParserTests 2>&1 | tail -20`
Expected: All 18 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add BaselineTests/OCR/InBodyDocumentParserTests.swift
git commit -m "test: add setField/getField round-trip tests for all field keys"
```

---

### Task 4: Create DocumentScannerView

**Files:**
- Create: `Baseline/Views/Body/DocumentScannerView.swift`

- [ ] **Step 1: Create the DocumentScannerView**

```swift
// Baseline/Views/Body/DocumentScannerView.swift
import SwiftUI
import VisionKit

/// Wraps Apple's VNDocumentCameraViewController for SwiftUI.
///
/// Provides built-in edge detection, perspective correction, and image cleanup.
/// On simulator, the document camera presents a photo library picker.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onScan: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (UIImage) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Use the first page — InBody sheets are single-page
            guard scan.pageCount > 0 else {
                onCancel()
                return
            }
            let image = scan.imageOfPage(at: 0)
            onScan(image)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            #if DEBUG
            print("[DocumentScannerView] Camera error: \(error)")
            #endif
            onCancel()
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Body/DocumentScannerView.swift
git commit -m "feat: add DocumentScannerView wrapping VNDocumentCameraViewController"
```

---

### Task 5: Wire up DocumentScannerView in ScanEntryFlow

**Files:**
- Modify: `Baseline/Views/Body/ScanEntryFlow.swift:239-266`

- [ ] **Step 1: Replace cameraStep to use DocumentScannerView**

In `ScanEntryFlow.swift`, replace the `cameraStep` method (lines 239-266):

Old code:
```swift
    private func cameraStep(vm: ScanEntryViewModel) -> some View {
        ZStack {
            ScanCameraView(
                onCapture: { image in
                    Task {
                        await vm.processImage(image)
                    }
                },
                onCancel: {
                    vm.goBack()
                }
            )
            .ignoresSafeArea()

            if vm.isProcessing {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(CadreColors.accent)
                    Text("Reading scan...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                }
            }
        }
    }
```

New code:
```swift
    private func cameraStep(vm: ScanEntryViewModel) -> some View {
        ZStack {
            DocumentScannerView(
                onScan: { image in
                    Task {
                        await vm.processImage(image)
                    }
                },
                onCancel: {
                    vm.goBack()
                }
            )
            .ignoresSafeArea()

            if vm.isProcessing {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(CadreColors.accent)
                    Text("Reading scan...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                }
            }
        }
    }
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Body/ScanEntryFlow.swift
git commit -m "feat: swap custom camera for Apple's document scanner in scan flow"
```

---

### Task 6: Wire up InBodyDocumentParser in ScanEntryViewModel

**Files:**
- Modify: `Baseline/ViewModels/ScanEntryViewModel.swift:144-159`

- [ ] **Step 1: Change processImage to call InBodyDocumentParser**

In `ScanEntryViewModel.swift`, replace line 148:

Old code:
```swift
        let result = await InBodyOCRParser.processImage(image)
```

New code:
```swift
        let result = await InBodyDocumentParser.parse(image: image)
```

- [ ] **Step 2: Run existing ViewModel tests to verify nothing broke**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntryViewModelTests 2>&1 | tail -20`
Expected: All existing tests PASS. These tests exercise populateFields/flow/save, not the parser call directly.

- [ ] **Step 3: Commit**

```bash
git add Baseline/ViewModels/ScanEntryViewModel.swift
git commit -m "feat: switch ViewModel to use InBodyDocumentParser instead of regex parser"
```

---

### Task 7: Add debug logging for on-device testing

**Files:**
- Modify: `Baseline/OCR/InBodyDocumentParser.swift`

- [ ] **Step 1: Add debug logging to the parse method**

Add logging after the extraction steps in the `parse` method, inside the `do` block, after `result.rawText = doc.transcript`:

```swift
            #if DEBUG
            // Log extraction results for on-device debugging
            print("=== DOCUMENT PARSER RESULTS ===")
            print("Tables found: \(doc.tables.count)")
            for (i, table) in doc.tables.enumerated() {
                print("  Table \(i): \(table.rows.count) rows")
                for (j, row) in table.rows.enumerated() {
                    let cells = row.map { $0.content.transcript }
                    print("    Row \(j): \(cells)")
                }
            }
            print("Paragraphs found: \(doc.paragraphs.count)")
            for (i, para) in doc.paragraphs.enumerated() {
                print("  Para \(i): \(para.transcript.prefix(100))")
            }
            print("--- PARSED FIELDS ---")
            let mirror = Mirror(reflecting: result)
            for child in mirror.children {
                guard let label = child.label,
                      label != "rawText",
                      label != "confidence",
                      label != "detectedUnit" else { continue }
                if let opt = child.value as? Double?, let val = opt {
                    print("  \(label): \(val)")
                } else if let date = child.value as? Date? {
                    if let d = date { print("  \(label): \(d)") }
                }
            }
            print("=== END PARSER RESULTS ===")
            #endif
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Baseline/OCR/InBodyDocumentParser.swift
git commit -m "feat: add debug logging to InBodyDocumentParser for on-device testing"
```

---

### Task 8: Run all tests and verify clean build

**Files:**
- No file changes — verification only.

- [ ] **Step 1: Run all tests**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30`
Expected: All tests PASS (InBodyDocumentParserTests + ScanEntryViewModelTests + any others).

- [ ] **Step 2: Verify clean build for device**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'generic/platform=iOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Tag as ready for device testing**

No commit needed — this is a verification step.
