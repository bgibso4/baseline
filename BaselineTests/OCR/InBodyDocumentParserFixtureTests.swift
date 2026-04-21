import XCTest
import UIKit
@testable import Baseline

/// End-to-end parser tests against real InBody 570 printouts. Each fixture
/// is a photo of a sheet (clean or with pen marks from gym staff); the test
/// drives the same `InBodyDocumentParser.parse(image:)` call the app uses
/// after document-camera capture.
///
/// ## Two modes
///
/// **Default (loose):** Asserts only that the parser runs without crashing
/// and extracts at least 5 of 7 core fields. Safe to run in CI — won't break
/// when Apple updates the Vision model in an iOS/Xcode release.
///
/// **Strict (`RUN_OCR_STRICT=1`):** Additionally asserts each core field
/// matches its human-verified ground-truth value within a small tolerance.
/// Use while actively working on parser accuracy (#24).
///
/// Either mode prints a per-field diagnostic table showing value, confidence,
/// flagged state, truth, and delta — that's the real value of these tests:
/// a living scorecard for parser work.
///
/// ## Fixture caveat
///
/// The fixtures are raw iPhone-camera JPEGs of sheets on a table. In
/// production the app gets `VNDocumentCameraScan` output, which is auto-
/// cropped, perspective-corrected, and contrast-enhanced before reaching
/// the parser. So the accuracy observed here is a worst case — better in
/// production — and specific failure modes may differ.
///
/// Ground-truth values were read directly from the printouts by a human.
/// Mass fields carry the sheet's native unit (lb here, per the gym's
/// InBody 570 config); the parser stores them raw in the named Double
/// properties. Unit conversion happens later in ScanEntryViewModel.buildPayload.
final class InBodyDocumentParserFixtureTests: XCTestCase {

    /// Whether to run the strict ground-truth assertions. Off by default so
    /// Xcode/iOS updates that shift Vision model outputs don't break CI.
    private var runStrictAssertions: Bool {
        ProcessInfo.processInfo.environment["RUN_OCR_STRICT"] == "1"
    }

    // MARK: - Ground Truth

    private struct GroundTruth {
        let weightKg: Double
        let skeletalMuscleMassKg: Double
        let bodyFatMassKg: Double
        let bodyFatPct: Double
        let totalBodyWaterL: Double
        let bmi: Double
        let basalMetabolicRate: Double
    }

    /// clean.jpg — 04.14.2026 07:18 InBody 570, no pen marks
    private let cleanTruth = GroundTruth(
        weightKg: 199.4,
        skeletalMuscleMassKg: 108.2,
        bodyFatMassKg: 12.0,
        bodyFatPct: 6.1,
        totalBodyWaterL: 137.1,
        bmi: 26.3,
        basalMetabolicRate: 2205
    )

    /// marked.jpg — 03.19.2026 07:37 InBody 570, pen circles on core fields
    private let markedTruth = GroundTruth(
        weightKg: 197.2,
        skeletalMuscleMassKg: 105.8,
        bodyFatMassKg: 14.2,
        bodyFatPct: 7.2,
        totalBodyWaterL: 134.0,
        bmi: 26.0,
        basalMetabolicRate: 2162
    )

    // MARK: - Tests

    func testCleanSheetParse() async throws {
        let image = try loadFixture(named: "clean")
        let result = await InBodyDocumentParser.parse(image: image)
        printDiagnostic(result: result, label: "clean.jpg", truth: cleanTruth)
        assertLooseContract(result: result, label: "clean")
        if runStrictAssertions {
            assertCoreFieldsMatchTruth(result: result, truth: cleanTruth, label: "clean")
        }
    }

    func testMarkedSheetParse() async throws {
        let image = try loadFixture(named: "marked")
        let result = await InBodyDocumentParser.parse(image: image)
        printDiagnostic(result: result, label: "marked.jpg", truth: markedTruth)
        assertLooseContract(result: result, label: "marked")
        if runStrictAssertions {
            assertCoreFieldsMatchTruth(result: result, truth: markedTruth, label: "marked")
        }
    }

    // MARK: - Assertions

    /// Default assertions: parser ran, extracted ≥5 of 7 core fields, and
    /// identified a scan date. These catch the parser regressing *entirely*
    /// (e.g. a schema change or crash) without pinning specific values that
    /// may drift as Apple updates the Vision model.
    private func assertLooseContract(result: InBodyParseResult, label: String) {
        let coreFields: [Double?] = [
            result.weightKg, result.skeletalMuscleMassKg, result.bodyFatMassKg,
            result.bodyFatPct, result.totalBodyWaterL, result.bmi,
            result.basalMetabolicRate,
        ]
        let populated = coreFields.compactMap { $0 }.count
        XCTAssertGreaterThanOrEqual(
            populated, 5,
            "\(label): parser must extract at least 5/7 core fields (got \(populated)). " +
            "If this fails, check the diagnostic table above — the parser either crashed, " +
            "is reading a completely wrong layout, or Vision model output shifted materially."
        )
        XCTAssertNotNil(result.scanDate, "\(label): scan date should be recognized")
    }

    /// Strict assertions (gated by `RUN_OCR_STRICT=1`). Asserts exact values
    /// within 0.1 tolerance on mass/ratio fields, 1.0 kcal on BMR. Use while
    /// actively iterating on parser accuracy (#24).
    private func assertCoreFieldsMatchTruth(result: InBodyParseResult, truth: GroundTruth, label: String) {
        XCTAssertEqual(result.weightKg ?? -1, truth.weightKg, accuracy: 0.1,
                       "\(label): weightKg mismatch")
        XCTAssertEqual(result.skeletalMuscleMassKg ?? -1, truth.skeletalMuscleMassKg, accuracy: 0.1,
                       "\(label): skeletalMuscleMassKg mismatch")
        XCTAssertEqual(result.bodyFatMassKg ?? -1, truth.bodyFatMassKg, accuracy: 0.1,
                       "\(label): bodyFatMassKg mismatch")
        XCTAssertEqual(result.bodyFatPct ?? -1, truth.bodyFatPct, accuracy: 0.1,
                       "\(label): bodyFatPct mismatch")
        XCTAssertEqual(result.totalBodyWaterL ?? -1, truth.totalBodyWaterL, accuracy: 0.1,
                       "\(label): totalBodyWaterL mismatch")
        XCTAssertEqual(result.bmi ?? -1, truth.bmi, accuracy: 0.1,
                       "\(label): bmi mismatch")
        XCTAssertEqual(result.basalMetabolicRate ?? -1, truth.basalMetabolicRate, accuracy: 1.0,
                       "\(label): basalMetabolicRate mismatch")
    }

    // MARK: - Diagnostics

    /// Emits a per-field table showing parsed value, confidence, whether it
    /// would have been flagged by the current threshold, and the ground-truth
    /// value. Critical for identifying wrong-but-high-confidence cases (#24).
    private func printDiagnostic(result: InBodyParseResult, label: String, truth: GroundTruth) {
        let rows: [(String, Double?, Double?)] = [
            ("weightKg", result.weightKg, truth.weightKg),
            ("skeletalMuscleMassKg", result.skeletalMuscleMassKg, truth.skeletalMuscleMassKg),
            ("bodyFatMassKg", result.bodyFatMassKg, truth.bodyFatMassKg),
            ("bodyFatPct", result.bodyFatPct, truth.bodyFatPct),
            ("totalBodyWaterL", result.totalBodyWaterL, truth.totalBodyWaterL),
            ("bmi", result.bmi, truth.bmi),
            ("basalMetabolicRate", result.basalMetabolicRate, truth.basalMetabolicRate),
            ("intracellularWaterL", result.intracellularWaterL, nil),
            ("extracellularWaterL", result.extracellularWaterL, nil),
            ("dryLeanMassKg", result.dryLeanMassKg, nil),
            ("leanBodyMassKg", result.leanBodyMassKg, nil),
            ("ecwTbwRatio", result.ecwTbwRatio, nil),
            ("skeletalMuscleIndex", result.skeletalMuscleIndex, nil),
            ("visceralFatLevel", result.visceralFatLevel, nil),
            ("rightArmLeanKg", result.rightArmLeanKg, nil),
            ("leftArmLeanKg", result.leftArmLeanKg, nil),
            ("trunkLeanKg", result.trunkLeanKg, nil),
            ("rightLegLeanKg", result.rightLegLeanKg, nil),
            ("leftLegLeanKg", result.leftLegLeanKg, nil),
            ("rightArmFatKg", result.rightArmFatKg, nil),
            ("leftArmFatKg", result.leftArmFatKg, nil),
            ("trunkFatKg", result.trunkFatKg, nil),
            ("rightLegFatKg", result.rightLegFatKg, nil),
            ("leftLegFatKg", result.leftLegFatKg, nil),
        ]

        let confidenceThreshold: Float = 0.75

        func pad(_ s: String, to width: Int, rightAlign: Bool = false) -> String {
            if s.count >= width { return s }
            let padding = String(repeating: " ", count: width - s.count)
            return rightAlign ? (padding + s) : (s + padding)
        }

        print("\n========== \(label) ==========")
        print(pad("field", to: 24) + " " + pad("value", to: 10, rightAlign: true) + " " +
              pad("conf", to: 6, rightAlign: true) + " " + pad("flagged", to: 9, rightAlign: true) + " " +
              pad("truth", to: 10, rightAlign: true) + " " + pad("delta", to: 10, rightAlign: true))
        print(String(repeating: "-", count: 80))

        var wrongButConfident: [String] = []
        var rightButFlagged: [String] = []

        for (key, value, truth) in rows {
            let conf = result.confidence[key] ?? 0
            let flagged = conf < confidenceThreshold
            let valueStr = value.map { String(format: "%.2f", $0) } ?? "-"
            let confStr = conf > 0 ? String(format: "%.2f", conf) : "-"
            let truthStr = truth.map { String(format: "%.2f", $0) } ?? ""
            let deltaStr: String = {
                guard let v = value, let t = truth else { return "" }
                let d = v - t
                return String(format: "%+.2f", d)
            }()
            let flaggedStr = conf > 0 ? (flagged ? "FLAG" : "ok") : "-"

            print(pad(key, to: 24) + " " + pad(valueStr, to: 10, rightAlign: true) + " " +
                  pad(confStr, to: 6, rightAlign: true) + " " + pad(flaggedStr, to: 9, rightAlign: true) + " " +
                  pad(truthStr, to: 10, rightAlign: true) + " " + pad(deltaStr, to: 10, rightAlign: true))

            // Surface the two interesting failure modes #24 cares about:
            if let v = value, let t = truth {
                let isRight = abs(v - t) < 0.1
                if !isRight && !flagged && conf > 0 {
                    wrongButConfident.append("\(key): parsed=\(v), truth=\(t), conf=\(conf)")
                }
                if isRight && flagged {
                    rightButFlagged.append("\(key): value=\(v), conf=\(conf)")
                }
            }
        }

        if !wrongButConfident.isEmpty {
            print("\n⚠️ WRONG BUT HIGH-CONFIDENCE (directly affects #24):")
            for s in wrongButConfident { print("   - \(s)") }
        }
        if !rightButFlagged.isEmpty {
            print("\n⚠️ RIGHT BUT FLAGGED LOW (false positive on flagging):")
            for s in rightButFlagged { print("   - \(s)") }
        }
        if let date = result.scanDate {
            print("\nscanDate: \(date)")
        } else {
            print("\nscanDate: (not extracted)")
        }
        print("========== end \(label) ==========\n")
    }

    // MARK: - Fixture Loading

    private func loadFixture(named name: String) throws -> UIImage {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "jpg") else {
            throw NSError(
                domain: "InBodyDocumentParserFixtureTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Fixture \(name).jpg not found in test bundle — check that it's listed in the BaselineTests target's Copy Bundle Resources build phase."]
            )
        }
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "InBodyDocumentParserFixtureTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Fixture \(name).jpg failed to decode as UIImage"]
            )
        }
        // iPhone JPEGs carry EXIF orientation; `image.cgImage` returns raw
        // pixels without applying it, so Vision sees the image sideways.
        // Bake orientation into the pixels by drawing into a new bitmap.
        return normalizeOrientation(image)
    }

    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
