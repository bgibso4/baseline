import Foundation
import Vision
import UIKit

// MARK: - InBodyDocumentParser
//
// Uses iOS 26's RecognizeDocumentsRequest (Vision framework) to extract structured
// data from InBody 570 body composition result sheet photos. Falls back to an empty
// result on any error.

struct InBodyDocumentParser {

    // MARK: - Label Map

    /// Maps lowercased, unit-stripped label strings to InBodyParseResult field keys.
    static let labelMap: [String: String] = [
        // Core
        "weight": "weightKg",
        "skeletal muscle mass": "skeletalMuscleMassKg",
        "smm": "skeletalMuscleMassKg",
        "body fat mass": "bodyFatMassKg",
        "percent body fat": "bodyFatPct",
        "pbf": "bodyFatPct",
        "total body water": "totalBodyWaterL",
        "tbw": "totalBodyWaterL",
        "bmi": "bmi",
        "body mass index": "bmi",
        "basal metabolic rate": "basalMetabolicRate",
        "bmr": "basalMetabolicRate",
        // Body Composition Analysis
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
        // ECW/TBW
        "ecw/tbw": "ecwTbwRatio",
        "ecw/tbw ratio": "ecwTbwRatio",
        // SMI
        "smi": "skeletalMuscleIndex",
        "skeletal muscle index": "skeletalMuscleIndex",
        // Visceral Fat
        "visceral fat level": "visceralFatLevel",
        "visceral fat area": "visceralFatLevel"
    ]

    // MARK: - Public API

    /// Parses an InBody 570 image using RecognizeDocumentsRequest and returns structured data.
    /// Returns an empty InBodyParseResult if CGImage conversion fails or the request throws.
    static func parse(image: UIImage) async -> InBodyParseResult {
        guard let cgImage = image.cgImage else {
            #if DEBUG
            Log.scan.debug("[InBodyDocumentParser] Failed to convert UIImage to CGImage")
            #endif
            return InBodyParseResult()
        }

        var result = InBodyParseResult()

        do {
            let request = RecognizeDocumentsRequest()
            let observations: [DocumentObservation] = try await request.perform(on: cgImage)

            guard let doc = observations.first?.document else {
                #if DEBUG
                Log.scan.debug("[InBodyDocumentParser] No document observations returned")
                #endif
                return result
            }

            let confidence = observations.first?.confidence ?? 0

            // Use the top-level text container's transcript as raw text
            result.rawText = doc.text.transcript

            // Primary: position-based extraction using paragraph bounding boxes
            extractByPosition(doc.paragraphs, into: &result)

            // Segmental lean: needs special handling (lbs vs % in same Y-band)
            extractSegmentalLean(doc.paragraphs, into: &result)

            // Cross-reference stays disabled — the history block lists PRIOR
            // scans, so on a sheet where today's scan is row N, history rows
            // 1..N-1 are different dates with different values. Enabling cross-
            // reference silently overwrote correct primaries with prior values
            // during #59 investigation. The disabled function is retained for
            // future work that figures out how to identify the current-scan
            // row (date matching against `result.scanDate`?).
            // crossReferenceHistory(doc.paragraphs, into: &result)

            // Fallback: table-based extraction for anything position missed
            extractFromTables(doc.tables, into: &result, confidence: confidence)

            // Date extraction
            extractDate(from: doc, into: &result)

            #if DEBUG
            let fields: [(String, Double?)] = [
                ("weightKg", result.weightKg), ("skeletalMuscleMassKg", result.skeletalMuscleMassKg),
                ("bodyFatMassKg", result.bodyFatMassKg), ("bodyFatPct", result.bodyFatPct),
                ("totalBodyWaterL", result.totalBodyWaterL), ("bmi", result.bmi),
                ("basalMetabolicRate", result.basalMetabolicRate),
                ("intracellularWaterL", result.intracellularWaterL),
                ("extracellularWaterL", result.extracellularWaterL),
                ("dryLeanMassKg", result.dryLeanMassKg), ("leanBodyMassKg", result.leanBodyMassKg),
                ("inBodyScore", result.inBodyScore),
                ("ecwTbwRatio", result.ecwTbwRatio), ("skeletalMuscleIndex", result.skeletalMuscleIndex),
                ("visceralFatLevel", result.visceralFatLevel),
                ("rightArmLeanKg", result.rightArmLeanKg), ("leftArmLeanKg", result.leftArmLeanKg),
                ("trunkLeanKg", result.trunkLeanKg),
                ("rightLegLeanKg", result.rightLegLeanKg), ("leftLegLeanKg", result.leftLegLeanKg),
                ("rightArmFatKg", result.rightArmFatKg), ("leftArmFatKg", result.leftArmFatKg),
                ("trunkFatKg", result.trunkFatKg),
                ("rightLegFatKg", result.rightLegFatKg), ("leftLegFatKg", result.leftLegFatKg)
            ]
            let summary = fields.compactMap { key, val in val.map { "\(key)=\($0)" } }.joined(separator: ", ")
            Log.scan.debug("InBody parsed fields: \(summary)")
            if let date = result.scanDate { Log.scan.debug("InBody scanDate: \(date)") }
            let populated = fields.compactMap { $0.1 }.count
            Log.scan.debug("InBody fields populated: \(populated)/\(fields.count)")
            #endif
        } catch {
            #if DEBUG
            Log.scan.debug("[InBodyDocumentParser] RecognizeDocumentsRequest error: \(error)")
            #endif
        }

        return result
    }

    /// Returns the InBodyParseResult field key for a given label string, or nil if unrecognized.
    /// Lowercases the input, strips parenthesized unit suffixes like "(kg)", and trims whitespace.
    static func fieldKey(for label: String) -> String? {
        let normalized = normalizeLabel(label)
        return labelMap[normalized]
    }

    // MARK: - Internal Extraction

    /// Walks table rows. First cell = label, subsequent cells = value.
    static func extractFromTables(
        _ tables: [DocumentObservation.Container.Table],
        into result: inout InBodyParseResult,
        confidence: Float
    ) {
        for table in tables {
            for row in table.rows {
                guard row.count >= 2 else { continue }
                let labelText = row[0].content.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let key = fieldKey(for: labelText) else { continue }
                // Only fill fields not already set by position extraction
                guard result.value(forKey: key) == nil else { continue }
                // Concatenate remaining cells as the value text
                let valueText = row[1...].map { $0.content.text.transcript }.joined(separator: " ")
                if let value = parseNumericValue(valueText) {
                    result.setValue(value, forKey: key)
                    if confidence > 0 {
                        result.confidence[key] = confidence
                    }
                }
            }
        }
    }

    // MARK: - Position-Based Extraction

    /// A region on the InBody 570 sheet where a specific field's value appears.
    /// Uses Vision's normalized coordinates (bottom-left origin: y=0 bottom, y=1 top).
    struct FieldRegion {
        let key: String
        let yRange: ClosedRange<Double>
        let xRange: ClosedRange<Double>
        /// If true, prefer values with bullet prefixes (•, -, =, m=) — used for bar chart fields.
        let preferBullet: Bool
        /// Plausible value range. Candidates outside are rejected and the next
        /// is tried — prevents impedance values, bar-chart markers, and other
        /// OCR debris from being silently stored as legitimate field values.
        /// nil = no range check.
        let validRange: ClosedRange<Double>?

        init(
            _ key: String,
            y: ClosedRange<Double>,
            x: ClosedRange<Double> = 0.0...1.0,
            bullet: Bool = false,
            valid: ClosedRange<Double>? = nil
        ) {
            self.key = key
            self.yRange = y
            self.xRange = x
            self.preferBullet = bullet
            self.validRange = valid
        }
    }

    /// Convenience alias — `SaneRange` lives in `InBodyParseResult.swift` next
    /// to the field definitions. Used by `FieldRegion.valid` and by the
    /// segmental lean extractor to reject impedance values, bar-chart markers,
    /// and OCR debris before they're written into a result.
    typealias SaneRange = InBodyParseResult.SaneRange

    // MARK: - Anchor-Relative Region Building

    /// Known section headers on the InBody 570 sheet, used as Y anchors.
    /// The sheet layout is fixed — relative spacing between fields never changes,
    /// only the absolute Y position shifts between scans.
    private static let sectionAnchors: [String: String] = [
        "body composition analysis": "bodyComp",
        "muscle-fat analysis": "muscleFat",
        "muscle- fat analysis": "muscleFat",
        "obesity analysis": "obesity",
        "obesity anaiysis": "obesity",
        "segmental lean analysis": "segLean",
        "ecw/tbw analysis": "ecwTbw",
        "segmental fat analysis": "segFat",
        "basal metabolic rate": "bmr",
        "visceral fat level": "visceralFat"
    ]

    /// Builds field regions dynamically by finding section headers and using offsets.
    static func buildRegions(from paragraphs: [DocumentObservation.Container.Text]) -> [FieldRegion] {
        // Find anchor Y positions from section headers
        var anchors: [String: Double] = [:]
        for para in paragraphs {
            let text = para.transcript.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"[\-:]$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let box = para.boundingRegion.boundingBox
            let centerY = box.origin.y + box.height / 2

            // Only consider left-column headers (x < 0.45) for main sections
            // and right-column (x > 0.60) for right-side sections
            for (label, anchor) in sectionAnchors {
                if text.hasPrefix(label) || text == label {
                    // Prefer the left-column instance for main sections
                    let isRightCol = box.origin.x > 0.60
                    let key = isRightCol ? anchor + "_right" : anchor
                    if anchors[key] == nil {
                        anchors[key] = centerY
                    }
                }
            }
        }

        #if DEBUG
        let anchorSummary = anchors.sorted(by: { $0.value > $1.value })
            .map { String(format: "%@=%.3f", $0.key, $0.value) }
            .joined(separator: ", ")
        Log.scan.debug("InBody anchors found: \(anchorSummary)")
        #endif

        var regions: [FieldRegion] = []

        // --- Body Composition Analysis grid ---
        // Values are in a fixed grid below the header.
        // Offsets measured from "Body Composition Analysis" header.
        if let bodyCompY = anchors["bodyComp"] {
            // The grid is below the header. Values at offsets from header:
            // ICW: -0.025, ECW: -0.050, DLM: -0.070, BFM: -0.095
            // TBW: -0.035 (different x), LBM: -0.050 (different x), Weight: -0.065 (different x)
            let m: Double = 0.012 // margin
            regions += [
                gridRegion("intracellularWaterL", y: bodyCompY - 0.040, m: m, x: 0.18...0.32, valid: SaneRange.icwLbs),
                gridRegion("extracellularWaterL", y: bodyCompY - 0.058, m: m, x: 0.18...0.32, valid: SaneRange.ecwLbs),
                gridRegion("totalBodyWaterL", y: bodyCompY - 0.048, m: m, x: 0.28...0.42, valid: SaneRange.tbwLbs),
                gridRegion("dryLeanMassKg", y: bodyCompY - 0.076, m: m, x: 0.18...0.32, valid: SaneRange.dlmLbs),
                gridRegion("leanBodyMassKg", y: bodyCompY - 0.058, m: m, x: 0.38...0.52, valid: SaneRange.lbmLbs),
                gridRegion("weightKg", y: bodyCompY - 0.076, m: m, x: 0.48...0.62, valid: SaneRange.weightLbs),
                gridRegion("bodyFatMassKg", y: bodyCompY - 0.100, m: m, x: 0.18...0.32, valid: SaneRange.bfmLbs)
            ]
        }

        // --- Muscle-Fat Analysis (bar charts) ---
        if let mfY = anchors["muscleFat"] {
            // Weight bar: ~0.040 below header, SMM: ~0.065, BFM: ~0.090
            let m: Double = 0.015
            regions += [
                barRegion("weightKg", y: mfY - 0.045, m: m, x: 0.20...0.62, valid: SaneRange.weightLbs),
                barRegion("skeletalMuscleMassKg", y: mfY - 0.072, m: m, x: 0.20...0.62, valid: SaneRange.smmLbs),
                barRegion("bodyFatMassKg", y: mfY - 0.100, m: m, x: 0.20...0.62, valid: SaneRange.bfmLbs)
            ]
        }

        // --- Obesity Analysis (bar charts) ---
        if let obY = anchors["obesity"] {
            // BMI: ~0.030 below header, PBF: ~0.055
            let m: Double = 0.015
            regions += [
                barRegion("bmi", y: obY - 0.030, m: m, x: 0.20...0.62, valid: SaneRange.bmi),
                barRegion("bodyFatPct", y: obY - 0.060, m: m, x: 0.20...0.62, valid: SaneRange.bfpPct)
            ]
        }

        // --- Segmental Lean Analysis ---
        // Each body part has two values very close in Y (~0.006 apart):
        //   - Lean mass in lbs (smaller number: 5-80 for arms/legs, 40-120 for trunk)
        //   - Sufficiency % (larger number: typically 80-200%)
        // Strategy: one wide Y-band per body part, extract both values at once
        // by filtering tick marks (round integers) and splitting by value range.
        // Handled separately in extractSegmentalLean() — no regions needed here.

        // --- ECW/TBW Analysis ---
        if let ecwY = anchors["ecwTbw"] {
            let m: Double = 0.020
            regions.append(
                barRegion("ecwTbwRatio", y: ecwY - 0.040, m: m, x: 0.20...0.62, valid: SaneRange.ecwTbw)
            )
        }

        // --- Right column: BMR ---
        if let bmrY = anchors["bmr_right"] ?? anchors["bmr"] {
            let m: Double = 0.015
            regions.append(
                gridRegion("basalMetabolicRate", y: bmrY - 0.015, m: m, x: 0.64...1.0, valid: SaneRange.bmrKcal)
            )
        }

        // --- Right column: SMI ---
        // SMI label is at a known position in right column
        for para in paragraphs {
            let text = para.transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let box = para.boundingRegion.boundingBox
            if text == "smi" && box.origin.x > 0.60 {
                let centerY = box.origin.y + box.height / 2
                let m: Double = 0.015
                regions.append(
                    gridRegion("skeletalMuscleIndex", y: centerY - 0.015, m: m, x: 0.64...1.0, valid: SaneRange.smi)
                )
                break
            }
        }

        // --- Right column: Visceral Fat Level ---
        if let vfY = anchors["visceralFat_right"] ?? anchors["visceralFat"] {
            let m: Double = 0.015
            // "Level N" appears just below the header, use the header's own line
            regions.append(
                gridRegion("visceralFatLevel", y: vfY - 0.020, m: m, x: 0.64...0.80, valid: SaneRange.visceralFat)
            )
        }

        // --- Right column: Segmental Fat ---
        if let sfY = anchors["segFat_right"] ?? anchors["segFat"] {
            // Right Arm: ~0.025 below header, Left Arm: ~0.042, Trunk: ~0.058, Right Leg: ~0.075, Left Leg: ~0.092
            let m: Double = 0.012
            let fatOffsets: [(String, String, Double)] = [
                ("rightArmFatKg", "rightArmFatPct", 0.025),
                ("leftArmFatKg", "leftArmFatPct", 0.042),
                ("trunkFatKg", "trunkFatPct", 0.058),
                ("rightLegFatKg", "rightLegFatPct", 0.075),
                ("leftLegFatKg", "leftLegFatPct", 0.092)
            ]
            for (kgKey, pctKey, offset) in fatOffsets {
                regions.append(gridRegion(kgKey, y: sfY - offset, m: m, x: 0.64...1.0, valid: SaneRange.segFatLbs))
                regions.append(gridRegion(pctKey, y: sfY - offset, m: m, x: 0.64...1.0, valid: SaneRange.segFatPct))
            }
        }

        return regions
    }

    /// Compact constructor for grid-style regions (a single labeled value at a
    /// known offset from an anchor). Centers the Y band on `y` with margin `m`.
    private static func gridRegion(
        _ key: String, y: Double, m: Double, x: ClosedRange<Double>, valid: ClosedRange<Double>
    ) -> FieldRegion {
        FieldRegion(key, y: (y - m)...(y + m), x: x, valid: valid)
    }

    /// Compact constructor for bar-chart regions (value appears as a bullet on
    /// a bar with tick-mark axis labels nearby). `preferBullet=true`.
    private static func barRegion(
        _ key: String, y: Double, m: Double, x: ClosedRange<Double>, valid: ClosedRange<Double>
    ) -> FieldRegion {
        FieldRegion(key, y: (y - m)...(y + m), x: x, bullet: true, valid: valid)
    }

    /// Primary extraction: use paragraph bounding boxes to locate values by position.
    static func extractByPosition(
        _ paragraphs: [DocumentObservation.Container.Text],
        into result: inout InBodyParseResult
    ) {
        let regions = buildRegions(from: paragraphs)

        for region in regions {
            // Skip if already populated (first match wins — body comp grid before bar chart)
            guard result.value(forKey: region.key) == nil else { continue }

            // Find paragraphs whose center falls within this region
            struct Candidate {
                let text: String
                let centerX: Double
                let height: Double
                let hasBullet: Bool
                /// True when the text contains more than one distinct number — a
                /// strong signal it's a bar-chart axis row (e.g. "10.0 18.0 30.0"),
                /// not a single labeled value.
                let multiNumber: Bool
            }
            var candidates: [Candidate] = []

            for para in paragraphs {
                let box = para.boundingRegion.boundingBox
                let centerY = box.origin.y + box.height / 2
                let centerX = box.origin.x + box.width / 2

                guard region.yRange.contains(centerY),
                      region.xRange.contains(centerX) else { continue }

                let text = para.transcript
                let hasBullet = text.range(of: #"^[^\dA-Za-z(\s]"#, options: .regularExpression) != nil
                    || text.range(of: #"^m[=\s]"#, options: .regularExpression) != nil
                let multiNumber = Self.numberCount(in: text) > 1
                candidates.append(Candidate(
                    text: text,
                    centerX: centerX,
                    height: box.height,
                    hasBullet: hasBullet,
                    multiNumber: multiNumber
                ))
            }

            guard !candidates.isEmpty else { continue }

            // For bar chart fields: prefer bullet-prefixed, then single-number,
            // then tallest, then non-tick-mark.
            let toTry: [Candidate]
            if region.preferBullet {
                let bulleted = candidates.filter { $0.hasBullet }
                if !bulleted.isEmpty {
                    toTry = bulleted.sorted { $0.height > $1.height }
                } else {
                    // No bullets: single-number candidates beat multi-number tick rows
                    // unconditionally (a paragraph holding "18.0 30.0 60.0 ..." is a
                    // bar-chart axis, not the labeled value). Within a group, sort
                    // by height desc, then by tick-mark likelihood.
                    toTry = candidates.sorted { a, b in
                        if a.multiNumber != b.multiNumber {
                            return !a.multiNumber  // single-number first
                        }
                        if abs(a.height - b.height) > 0.002 {
                            return a.height > b.height  // taller wins
                        }
                        return Self.tickMarkScore(a.text) < Self.tickMarkScore(b.text)
                    }
                }
            } else {
                toTry = candidates
            }

            // Extract the first valid numeric value
            let wasOnlyCandidate = candidates.count == 1
            for candidate in toTry {
                // Strip any non-alphanumeric prefix characters
                let cleaned = candidate.text.replacingOccurrences(
                    of: #"^[^\dA-Za-z(]*"#, with: "", options: .regularExpression
                )

                // Visceral fat: "Level l" / "Level I" → "Level 1" (OCR confuses
                // small digits with similarly-shaped letters on this row).
                let textForRegion: String = region.key == "visceralFatLevel"
                    ? Self.recoverVisceralFatDigits(candidate.text)
                    : cleaned

                guard let value = parseNumericValue(textForRegion) else { continue }

                // Reject garbled bullet candidates that parse to 0 — no real InBody value is 0.0
                if candidate.hasBullet && value < 0.1 { continue }

                // Reject values outside the field's plausible range — keeps
                // impedance-table debris and bar-chart axis markers out.
                if let range = region.validRange, !range.contains(value) { continue }

                // For bar-chart regions: reject tick-mark-shaped values when
                // the candidate isn't a bullet hit. The actual value bullet may
                // have been illegible (pen marks, faint print) — surfacing a
                // tick mark as the value is worse than leaving the field nil,
                // which the cross-field validator will flag for user review.
                if region.preferBullet && !candidate.hasBullet
                    && Self.tickMarkScore(candidate.text) > 0 { continue }

                // Confidence: bullet > height-sorted > ambiguous
                let conf: Float = candidate.hasBullet ? 0.9
                    : wasOnlyCandidate ? 0.85
                    : (candidate.height > 0.012) ? 0.7
                    : 0.5

                // For segmental fat, parse "X.Xlbs) | Y.Y%" pattern
                if region.key.hasSuffix("FatPct"), let pct = parseSegmentalFatPct(candidate.text) {
                    result.setValue(pct, forKey: region.key)
                } else if region.key.hasSuffix("FatKg"), let kg = parseSegmentalFatKg(candidate.text) {
                    result.setValue(kg, forKey: region.key)
                } else {
                    result.setValue(value, forKey: region.key)
                }
                result.confidence[region.key] = conf
                break
            }
        }
    }

    /// Parses "X.Xlbs) | Y.Y%" or "X.Xlbs) - Y.Y%" or "X.Xlbs) Y.Y%" to extract the percentage.
    /// The separator (| or -) is optional because OCR sometimes drops it.
    private static func parseSegmentalFatPct(_ text: String) -> Double? {
        let pattern = #"bs\)\s*[\|\-]?\s*(\d+\.?\d*)\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    /// Parses "X.Xlbs)" to extract the kg/lbs value.
    /// Handles OCR artifacts like "0. 21bs)" → 0.2 and "6.81bs)" → 6.8
    private static func parseSegmentalFatKg(_ text: String) -> Double? {
        // First collapse spaces in decimals: "0. 21bs)" → "0.21bs)"
        let collapsed = text.replacingOccurrences(
            of: #"(\d+)\.\s+(\d)"#, with: "$1.$2", options: .regularExpression
        )
        // Match number before "lbs)" or "Ibs)" or "bs)" — OCR renders l/I/1 inconsistently
        let pattern = #"(\d+\.?\d*)\s*[Il1|]?[Il1|]?bs\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: collapsed, range: NSRange(collapsed.startIndex..., in: collapsed)),
              let range = Range(match.range(at: 1), in: collapsed) else { return nil }
        return Double(collapsed[range])
    }

    // MARK: - Segmental Lean Extraction

    /// Extracts segmental lean mass (lbs) and sufficiency (%) for all 5 body parts.
    ///
    /// Strategy: For each body part, find ALL non-tick-mark decimal values in its Y-band.
    /// The two actual values have decimal parts (11.49, 138.0) while tick marks are
    /// round integers (100, 110, 130, 150). Among the decimals, the one at HIGHER Y
    /// (higher on page, Vision bottom-left origin) is lbs, the one at LOWER Y is %.
    static func extractSegmentalLean(
        _ paragraphs: [DocumentObservation.Container.Text],
        into result: inout InBodyParseResult
    ) {
        // Find the segmental lean anchor
        var segLeanY: Double?
        for para in paragraphs {
            let text = para.transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let box = para.boundingRegion.boundingBox
            if text.hasPrefix("segmental lean analysis") && box.origin.x < 0.45 {
                segLeanY = box.origin.y + box.height / 2
                break
            }
        }
        guard let anchorY = segLeanY else { return }

        // Body parts with their Y offsets from the anchor, field keys, and the
        // plausible kg range (rejects impedance values and bar-chart markers).
        // The pct range is shared across all segments.
        let segments: [(kgKey: String, pctKey: String, offset: Double, kgRange: ClosedRange<Double>)] = [
            ("rightArmLeanKg", "rightArmLeanPct", 0.042, SaneRange.segLeanArmLbs),
            ("leftArmLeanKg", "leftArmLeanPct", 0.074, SaneRange.segLeanArmLbs),
            ("trunkLeanKg", "trunkLeanPct", 0.107, SaneRange.segLeanTrunkLbs),
            ("rightLegLeanKg", "rightLegLeanPct", 0.142, SaneRange.segLeanLegLbs),
            ("leftLegLeanKg", "leftLegLeanPct", 0.177, SaneRange.segLeanLegLbs)
        ]

        for seg in segments {
            guard result.value(forKey: seg.kgKey) == nil else { continue }

            let centerTarget = anchorY - seg.offset
            let yRange = (centerTarget - 0.018)...(centerTarget + 0.018)

            // Collect raw paragraphs in the region
            struct RawPara {
                let text: String
                let centerY: Double
                let centerX: Double
            }
            var rawParas: [RawPara] = []
            for para in paragraphs {
                let box = para.boundingRegion.boundingBox
                let centerY = box.origin.y + box.height / 2
                let centerX = box.origin.x + box.width / 2
                guard yRange.contains(centerY), centerX > 0.35, centerX < 0.62 else { continue }
                rawParas.append(RawPara(text: para.transcript, centerY: centerY, centerX: centerX))
            }

            // Merge split decimals: "11." + "38" at similar Y → "11.38"
            // OCR sometimes splits a number with a decimal into two paragraphs
            var merged: [RawPara] = []
            var skip: Set<Int> = []
            for (i, p) in rawParas.enumerated() {
                if skip.contains(i) { continue }
                let stripped = p.text.replacingOccurrences(of: #"^[^\d]*"#, with: "", options: .regularExpression)
                if stripped.hasSuffix(".") || stripped.hasSuffix(". ") {
                    // Look for a digit-starting paragraph at very close Y
                    for j in (i + 1)..<rawParas.count {
                        if skip.contains(j) { continue }
                        let q = rawParas[j]
                        if abs(p.centerY - q.centerY) < 0.005,
                           q.text.first?.isNumber == true {
                            let combined = stripped.trimmingCharacters(in: .whitespaces) + q.text
                            merged.append(RawPara(text: combined, centerY: p.centerY, centerX: p.centerX))
                            skip.insert(j)
                            skip.insert(i)
                            break
                        }
                    }
                    if !skip.contains(i) { merged.append(p) }
                } else {
                    merged.append(p)
                }
            }

            // Parse values from merged paragraphs
            struct LeanCandidate {
                let value: Double
                let centerY: Double
                let text: String
            }
            var candidates: [LeanCandidate] = []

            for p in merged {
                let cleaned = p.text.replacingOccurrences(
                    of: #"^[^\dA-Za-z(]*"#, with: "", options: .regularExpression
                )
                let collapsed = cleaned.replacingOccurrences(
                    of: #"(\d+)\.\s+(\d)"#, with: "$1.$2", options: .regularExpression
                )
                guard let value = parseNumericValue(collapsed) else { continue }

                // Filter tick marks: round multiples of 5 at ≥50
                let isTickMark = value.truncatingRemainder(dividingBy: 5.0) == 0
                    && value == value.rounded()
                    && value >= 50
                if isTickMark { continue }

                candidates.append(LeanCandidate(value: value, centerY: p.centerY, text: p.text))
            }

            // Sort by Y descending (higher Y = higher on page = lbs row, which is on top)
            let sorted = candidates.sorted { $0.centerY > $1.centerY }

            // Partition by which row the value plausibly belongs to. Values
            // outside both ranges are debris (impedance markers, garbled OCR)
            // and don't make it into either slot.
            let kgRange = seg.kgRange
            let pctRange = SaneRange.segLeanPct
            let kgCandidates = sorted.filter { kgRange.contains($0.value) }
            let pctCandidates = sorted.filter { pctRange.contains($0.value) }

            if let kg = kgCandidates.first {
                result.setValue(kg.value, forKey: seg.kgKey)
                result.confidence[seg.kgKey] = 0.8
            }
            if let pct = pctCandidates.first {
                result.setValue(pct.value, forKey: seg.pctKey)
                result.confidence[seg.pctKey] = 0.8
            }
        }
    }

    // MARK: - Body Composition History Cross-Reference

    /// The Body Composition History section (near bottom of page) lists 4 key metrics
    /// in a simple vertical layout with no bar charts or tick marks:
    ///   Weight, SMM (Skeletal Muscle Mass), PBF (Body Fat %), ECW/TBW
    ///
    /// These are the exact fields that bar chart extraction struggles with most.
    /// We use these as a cross-reference: if the primary extraction got a value,
    /// compare with history; if they agree, boost confidence. If primary missed it,
    /// use the history value.
    static func crossReferenceHistory(
        _ paragraphs: [DocumentObservation.Container.Text],
        into result: inout InBodyParseResult
    ) {
        // Find the "Body Composition History" anchor
        var historyY: Double?
        for para in paragraphs {
            let text = para.transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let box = para.boundingRegion.boundingBox
            if text.hasPrefix("body composition history") && box.origin.x < 0.45 {
                historyY = box.origin.y + box.height / 2
                break
            }
        }
        guard let anchorY = historyY else {
            #if DEBUG
            Log.scan.debug("[History] Body Composition History anchor not found")
            #endif
            return
        }

        // The history section has 4 label-value pairs below the header.
        // Labels are at x≈0.05, values at x≈0.19-0.26.
        // Layout (offsets from anchor, going DOWN the page = decreasing Y):
        //   Weight: ~0.030 below header
        //   SMM:    ~0.060 below
        //   PBF:    ~0.092 below
        //   ECW/TBW: ~0.135 below
        let historyFields: [(key: String, labelPattern: String, offset: Double, saneRange: ClosedRange<Double>)] = [
            ("weightKg", "weight", 0.030, 50...600),
            ("skeletalMuscleMassKg", "smm", 0.060, 30...300),
            ("bodyFatPct", "pbf", 0.092, 1...70),
            ("ecwTbwRatio", "ecw", 0.135, 0.300...0.500)
        ]

        for field in historyFields {
            let targetY = anchorY - field.offset
            let yRange = (targetY - 0.015)...(targetY + 0.015)

            // Find the numeric value in this Y band (x > 0.15 to skip labels)
            var bestValue: Double?
            var bestHeight: Double = 0

            for para in paragraphs {
                let box = para.boundingRegion.boundingBox
                let centerY = box.origin.y + box.height / 2
                let centerX = box.origin.x + box.width / 2

                guard yRange.contains(centerY), centerX > 0.15, centerX < 0.35 else { continue }

                let text = para.transcript
                let collapsed = text.replacingOccurrences(
                    of: #"(\d+)\.\s+(\d)"#, with: "$1.$2", options: .regularExpression
                )
                // Strip any leading non-numeric chars (OCR artifacts)
                let cleaned = collapsed.replacingOccurrences(
                    of: #"^[^\d]*"#, with: "", options: .regularExpression
                )
                guard let value = parseNumericValue(cleaned), value > 0.01 else { continue }

                // Prefer taller text (actual values vs noise)
                if box.height > bestHeight {
                    bestValue = value
                    bestHeight = box.height
                }
            }

            guard let historyValue = bestValue else { continue }

            // Validate: history value must be in sane range (OCR can garble numbers)
            let historyIsValid = field.saneRange.contains(historyValue)

            #if DEBUG
            if !historyIsValid {
                Log.scan.debug(
                    "[History] \(field.key): history=\(historyValue) OUTSIDE sane range \(field.saneRange), ignoring"
                )
            }
            #endif

            let currentValue = result.value(forKey: field.key)
            let currentConf = result.confidence[field.key] ?? 0
            let currentIsValid = currentValue.map { field.saneRange.contains($0) } ?? false

            if let current = currentValue {
                // Compare: if history agrees (within 1%), boost confidence
                let pctDiff = abs(current - historyValue) / max(abs(historyValue), 0.001)
                if pctDiff < 0.01 {
                    result.confidence[field.key] = max(currentConf, 0.95)
                    #if DEBUG
                    Log.scan.debug("[History] \(field.key): confirmed \(current) (history=\(historyValue)) conf→0.95")
                    #endif
                } else if historyIsValid && !currentIsValid {
                    // Primary is out of range, history is valid → use history
                    result.setValue(historyValue, forKey: field.key)
                    result.confidence[field.key] = 0.85
                    #if DEBUG
                    Log.scan.debug(
                        "[History] \(field.key): primary \(current) out of range, using history \(historyValue)"
                    )
                    #endif
                } else if historyIsValid {
                    // Both in range but disagree → trust history (simpler source)
                    result.setValue(historyValue, forKey: field.key)
                    result.confidence[field.key] = 0.85
                    #if DEBUG
                    Log.scan.debug("[History] \(field.key): overriding \(current) → \(historyValue) (history wins)")
                    #endif
                } else {
                    // History is invalid, keep primary
                    #if DEBUG
                    Log.scan.debug(
                        "[History] \(field.key): keeping primary \(current), history \(historyValue) invalid"
                    )
                    #endif
                }
            } else if historyIsValid {
                // Primary missed it, history is valid → use it
                result.setValue(historyValue, forKey: field.key)
                result.confidence[field.key] = 0.8
                #if DEBUG
                Log.scan.debug("[History] \(field.key): filled from history = \(historyValue)")
                #endif
            }
        }
    }

    /// Attempts to extract the scan date from the document container's detectedData,
    /// then falls back to regex parsing for formats like "01/15/2026" or "2026.01.15".
    ///
    /// The detectedData is accessed via doc.text.detectedData. Each item's .match.details
    /// may be .calendarEvent(event) where event.startDate is the detected Date.
    static func extractDate(from doc: DocumentObservation.Container, into result: inout InBodyParseResult) {
        // Try detectedData first (calendar events contain dates)
        for dataMatch in doc.text.detectedData {
            if case .calendarEvent(let event) = dataMatch.match.details,
               let date = event.startDate {
                result.scanDate = date
                return
            }
        }

        // Regex fallback: parse dates from text transcript
        let transcript = doc.text.transcript
        let dateFormats: [(String, [Int])] = [
            // MM/DD/YYYY
            (#"(\d{1,2})/(\d{1,2})/(\d{4})"#, [1, 2, 3]),
            // YYYY.MM.DD
            (#"(\d{4})\.(\d{1,2})\.(\d{1,2})"#, [3, 2, 1]),
            // MM. DD. YYYY (InBody 570 format)
            (#"(\d{2})\.\s*(\d{2})\.\s*(\d{4})"#, [1, 2, 3])
        ]

        for (pattern, order) in dateFormats {
            guard result.scanDate == nil else { break }
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript))
            else { continue }

            var components = [Int]()
            for groupIndex in 1...3 {
                guard let range = Range(match.range(at: groupIndex), in: transcript),
                      let n = Int(transcript[range]) else { continue }
                components.append(n)
            }
            guard components.count == 3 else { continue }

            // order values are 1-based indices into components for [month, day, year]
            let month = components[order[0] - 1]
            let day   = components[order[1] - 1]
            let year  = components[order[2] - 1]

            if month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 2000 {
                var dc = DateComponents()
                dc.month = month; dc.day = day; dc.year = year
                result.scanDate = Calendar.current.date(from: dc)
            }
        }
    }

    // MARK: - Numeric Parsing

    /// Strips units and whitespace from a value string and returns a Double.
    /// Handles: "89.5 kg", "17.1%", "1842 kcal", "0.380", "105. 8" (OCR space in decimal).
    static func parseNumericValue(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // First, collapse OCR-inserted spaces within numbers: "105. 8" → "105.8", "0. 369" → "0.369"
        let collapsed = trimmed.replacingOccurrences(
            of: #"(\d+)\.\s+(\d)"#, with: "$1.$2", options: .regularExpression
        )

        // Extract the first number using regex (handles embedded units)
        let pattern = #"-?\d+\.?\d*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: collapsed, range: NSRange(collapsed.startIndex..., in: collapsed)),
              let range = Range(match.range, in: collapsed)
        else { return nil }

        return Double(collapsed[range])
    }

    // MARK: - Private Helpers

    /// Scores how likely a text value is a tick mark (higher = more likely a tick mark).
    /// Tick marks on InBody bar charts are round numbers: multiples of 5 for BMI/PBF,
    /// multiples of 10 for muscle/fat bars. Actual values (7.2, 26.0, 105.8, 0.369)
    /// don't fall on these grids.
    private static func tickMarkScore(_ text: String) -> Int {
        let step1 = text.replacingOccurrences(of: #"^[^\dA-Za-z(]*"#, with: "", options: .regularExpression)
        let cleaned = step1.replacingOccurrences(of: #"(\d+)\.\s+(\d)"#, with: "$1.$2", options: .regularExpression)
        guard let value = parseNumericValue(cleaned) else { return 0 }

        // Exact multiples of 5 with no meaningful fractional part → almost certainly a tick mark
        if value >= 5 && value.truncatingRemainder(dividingBy: 5.0) == 0 {
            return 2
        }
        // Exact integers that are multiples of common tick spacings
        if value == value.rounded() && value >= 10 {
            return 1
        }
        return 0
    }

    /// Counts the number of distinct numeric tokens (`\d+\.?\d*`) in a string.
    /// Used to distinguish single-value paragraphs ("6.1") from bar-chart axis
    /// rows that hold multiple numbers ("18.0 30.0 60.0 ...").
    private static func numberCount(in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"\d+\.?\d*"#) else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, range: range)
    }

    /// On the Visceral Fat Level row, OCR consistently misreads single digits
    /// as similarly-shaped letters ("Level 1" → "Level l", "Level 7" → "Level T").
    /// Restore the digit form so `parseNumericValue` can extract it.
    /// Only applied within the visceralFatLevel region — keeps the substitution
    /// targeted instead of risking false positives on other fields.
    static func recoverVisceralFatDigits(_ text: String) -> String {
        var s = text
        // Substitute only when the surrounding context is "Level ?" so we
        // don't corrupt unrelated text that happens to be in the region.
        guard s.lowercased().contains("level") else { return text }
        let map: [Character: Character] = [
            "l": "1", "I": "1", "|": "1",
            "O": "0", "o": "0",
            "Z": "2", "z": "2",
            "T": "7"
        ]
        s = String(s.map { map[$0] ?? $0 })
        return s
    }

    /// Lowercases, strips parenthesized unit suffixes (e.g. "(kg)"), and trims whitespace.
    private static func normalizeLabel(_ label: String) -> String {
        var s = label.lowercased()
        // Strip parenthesized units: "(kg)", "(lbs)", "(l)", "(kcal)", etc.
        if let regex = try? NSRegularExpression(pattern: #"\s*\([^)]*\)"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
