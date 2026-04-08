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
        "visceral fat area": "visceralFatLevel",
    ]

    // MARK: - Public API

    /// Parses an InBody 570 image using RecognizeDocumentsRequest and returns structured data.
    /// Returns an empty InBodyParseResult if CGImage conversion fails or the request throws.
    static func parse(image: UIImage) async -> InBodyParseResult {
        guard let cgImage = image.cgImage else {
            #if DEBUG
            print("[InBodyDocumentParser] Failed to convert UIImage to CGImage")
            #endif
            return InBodyParseResult()
        }

        var result = InBodyParseResult()

        do {
            let request = RecognizeDocumentsRequest()
            let observations: [DocumentObservation] = try await request.perform(on: cgImage)

            guard let doc = observations.first?.document else {
                #if DEBUG
                print("[InBodyDocumentParser] No document observations returned")
                #endif
                return result
            }

            let confidence = observations.first?.confidence ?? 0

            // Use the top-level text container's transcript as raw text
            result.rawText = doc.text.transcript

            #if DEBUG
            print("[InBodyDocumentParser] Tables found: \(doc.tables.count)")
            print("[InBodyDocumentParser] Paragraphs found: \(doc.paragraphs.count)")
            #endif

            // Primary: position-based extraction using paragraph bounding boxes
            extractByPosition(doc.paragraphs, into: &result)

            // Fallback: table-based extraction for anything position missed
            extractFromTables(doc.tables, into: &result, confidence: confidence)

            // Date extraction
            extractDate(from: doc, into: &result)

            #if DEBUG
            print("=== DOCUMENT PARSER RESULTS ===")
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
                ("rightLegFatKg", result.rightLegFatKg), ("leftLegFatKg", result.leftLegFatKg),
            ]
            print("--- PARSED FIELDS ---")
            for (key, val) in fields {
                if let v = val { print("  \(key): \(v)") }
            }
            if let date = result.scanDate { print("  scanDate: \(date)") }
            let populated = fields.compactMap { $0.1 }.count
            print("--- \(populated)/\(fields.count) fields populated ---")
            print("=== END PARSER RESULTS ===")
            #endif

        } catch {
            #if DEBUG
            print("[InBodyDocumentParser] RecognizeDocumentsRequest error: \(error)")
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
        for (tableIndex, table) in tables.enumerated() {
            #if DEBUG
            print("[InBodyDocumentParser] Table \(tableIndex): \(table.rows.count) rows")
            #endif
            for row in table.rows {
                guard row.count >= 2 else { continue }
                let labelText = row[0].content.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let key = fieldKey(for: labelText) else { continue }
                // Concatenate remaining cells as the value text
                let valueText = row[1...].map { $0.content.text.transcript }.joined(separator: " ")
                if let value = parseNumericValue(valueText) {
                    setField(key, value: value, on: &result)
                    if confidence > 0 {
                        result.confidence[key] = confidence
                    }
                    #if DEBUG
                    print("[InBodyDocumentParser] Table field: \(key) = \(value) (confidence: \(confidence))")
                    #endif
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

        init(_ key: String, y: ClosedRange<Double>, x: ClosedRange<Double> = 0.0...1.0, bullet: Bool = false) {
            self.key = key
            self.yRange = y
            self.xRange = x
            self.preferBullet = bullet
        }
    }

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
        "ecw/tbw": "ecwTbw",
        "segmental fat analysis": "segFat",
        "basal metabolic rate": "bmr",
        "visceral fat level": "visceralFat",
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
        print("=== ANCHORS FOUND ===")
        for (key, y) in anchors.sorted(by: { $0.value > $1.value }) {
            print(String(format: "  %@ = %.3f", key, y))
        }
        print("=== END ANCHORS ===")
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
                FieldRegion("intracellularWaterL",  y: (bodyCompY - 0.040 - m)...(bodyCompY - 0.040 + m), x: 0.18...0.32),
                FieldRegion("extracellularWaterL",  y: (bodyCompY - 0.058 - m)...(bodyCompY - 0.058 + m), x: 0.18...0.32),
                FieldRegion("totalBodyWaterL",      y: (bodyCompY - 0.048 - m)...(bodyCompY - 0.048 + m), x: 0.28...0.42),
                FieldRegion("dryLeanMassKg",        y: (bodyCompY - 0.076 - m)...(bodyCompY - 0.076 + m), x: 0.18...0.32),
                FieldRegion("leanBodyMassKg",       y: (bodyCompY - 0.058 - m)...(bodyCompY - 0.058 + m), x: 0.38...0.52),
                FieldRegion("weightKg",             y: (bodyCompY - 0.076 - m)...(bodyCompY - 0.076 + m), x: 0.48...0.62),
                FieldRegion("bodyFatMassKg",        y: (bodyCompY - 0.100 - m)...(bodyCompY - 0.100 + m), x: 0.18...0.32),
            ]
        }

        // --- Muscle-Fat Analysis (bar charts) ---
        if let mfY = anchors["muscleFat"] {
            // Weight bar: ~0.040 below header, SMM: ~0.065, BFM: ~0.090
            let m: Double = 0.015
            regions += [
                FieldRegion("weightKg",             y: (mfY - 0.045 - m)...(mfY - 0.045 + m), x: 0.20...0.62, bullet: true),
                FieldRegion("skeletalMuscleMassKg", y: (mfY - 0.072 - m)...(mfY - 0.072 + m), x: 0.20...0.62, bullet: true),
                FieldRegion("bodyFatMassKg",        y: (mfY - 0.100 - m)...(mfY - 0.100 + m), x: 0.20...0.62, bullet: true),
            ]
        }

        // --- Obesity Analysis (bar charts) ---
        if let obY = anchors["obesity"] {
            // BMI: ~0.030 below header, PBF: ~0.055
            let m: Double = 0.015
            regions += [
                FieldRegion("bmi",       y: (obY - 0.030 - m)...(obY - 0.030 + m), x: 0.20...0.62, bullet: true),
                FieldRegion("bodyFatPct", y: (obY - 0.060 - m)...(obY - 0.060 + m), x: 0.20...0.62, bullet: true),
            ]
        }

        // --- Segmental Lean Analysis ---
        if let slY = anchors["segLean"] {
            // Right Arm: ~0.040 below, Left Arm: ~0.072, Trunk: ~0.105, Right Leg: ~0.140, Left Leg: ~0.175
            let m: Double = 0.015
            let offsets: [(String, Double)] = [
                ("rightArmLeanKg",  0.040),
                ("leftArmLeanKg",   0.072),
                ("trunkLeanKg",     0.105),
                ("rightLegLeanKg",  0.140),
                ("leftLegLeanKg",   0.175),
            ]
            for (key, offset) in offsets {
                regions.append(FieldRegion(key, y: (slY - offset - m)...(slY - offset + m), x: 0.35...0.55, bullet: true))
            }
            // Sufficiency percentages are in the same rows but further right
            let pctOffsets: [(String, Double)] = [
                ("rightArmLeanPct",  0.040),
                ("leftArmLeanPct",   0.072),
                ("trunkLeanPct",     0.105),
                ("rightLegLeanPct",  0.140),
                ("leftLegLeanPct",   0.175),
            ]
            for (key, offset) in pctOffsets {
                regions.append(FieldRegion(key, y: (slY - offset - m)...(slY - offset + m), x: 0.42...0.62))
            }
        }

        // --- ECW/TBW Analysis ---
        if let ecwY = anchors["ecwTbw"] {
            let m: Double = 0.020
            regions.append(FieldRegion("ecwTbwRatio", y: (ecwY - 0.040 - m)...(ecwY - 0.040 + m), x: 0.20...0.62, bullet: true))
        }

        // --- Right column: BMR ---
        if let bmrY = anchors["bmr_right"] ?? anchors["bmr"] {
            let m: Double = 0.015
            regions.append(FieldRegion("basalMetabolicRate", y: (bmrY - 0.015 - m)...(bmrY - 0.015 + m), x: 0.64...1.0))
        }

        // --- Right column: SMI ---
        // SMI label is at a known position in right column
        for para in paragraphs {
            let text = para.transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let box = para.boundingRegion.boundingBox
            if text == "smi" && box.origin.x > 0.60 {
                let centerY = box.origin.y + box.height / 2
                let m: Double = 0.015
                regions.append(FieldRegion("skeletalMuscleIndex", y: (centerY - 0.015 - m)...(centerY - 0.015 + m), x: 0.64...1.0))
                break
            }
        }

        // --- Right column: Visceral Fat Level ---
        if let vfY = anchors["visceralFat_right"] ?? anchors["visceralFat"] {
            let m: Double = 0.015
            // "Level N" appears just below the header, use the header's own line
            regions.append(FieldRegion("visceralFatLevel", y: (vfY - 0.020 - m)...(vfY - 0.020 + m), x: 0.64...0.80))
        }

        // --- Right column: Segmental Fat ---
        if let sfY = anchors["segFat_right"] ?? anchors["segFat"] {
            // Right Arm: ~0.025 below header, Left Arm: ~0.042, Trunk: ~0.058, Right Leg: ~0.075, Left Leg: ~0.092
            let m: Double = 0.012
            let fatOffsets: [(String, String, Double)] = [
                ("rightArmFatKg", "rightArmFatPct", 0.025),
                ("leftArmFatKg",  "leftArmFatPct",  0.042),
                ("trunkFatKg",    "trunkFatPct",    0.058),
                ("rightLegFatKg", "rightLegFatPct", 0.075),
                ("leftLegFatKg",  "leftLegFatPct",  0.092),
            ]
            for (kgKey, pctKey, offset) in fatOffsets {
                let yBand = (sfY - offset - m)...(sfY - offset + m)
                regions.append(FieldRegion(kgKey, y: yBand, x: 0.64...1.0))
                regions.append(FieldRegion(pctKey, y: yBand, x: 0.64...1.0))
            }
        }

        return regions
    }

    /// Primary extraction: use paragraph bounding boxes to locate values by position.
    static func extractByPosition(
        _ paragraphs: [DocumentObservation.Container.Text],
        into result: inout InBodyParseResult
    ) {
        #if DEBUG
        print("=== PARAGRAPH POSITIONS (Y ascending) ===")
        let sorted = paragraphs.enumerated().sorted {
            $0.element.boundingRegion.boundingBox.origin.y <
            $1.element.boundingRegion.boundingBox.origin.y
        }
        for (idx, para) in sorted {
            let box = para.boundingRegion.boundingBox
            let text = para.transcript.prefix(60)
            print(String(format: "  [%3d] y=%.3f x=%.3f w=%.3f h=%.3f | %@",
                         idx, box.origin.y, box.origin.x, box.width, box.height, String(text)))
        }
        print("=== END POSITIONS ===")
        #endif

        let regions = buildRegions(from: paragraphs)

        for region in regions {
            // Skip if already populated (first match wins — body comp grid before bar chart)
            guard getField(region.key, from: result) == nil else { continue }

            // Find paragraphs whose center falls within this region
            var candidates: [(text: String, centerX: Double, hasBullet: Bool)] = []

            for para in paragraphs {
                let box = para.boundingRegion.boundingBox
                let centerY = box.origin.y + box.height / 2
                let centerX = box.origin.x + box.width / 2

                guard region.yRange.contains(centerY),
                      region.xRange.contains(centerX) else { continue }

                let text = para.transcript
                let hasBullet = text.range(of: #"^[=•\-·mш]*\s*\d"#, options: .regularExpression) != nil
                candidates.append((text: text, centerX: centerX, hasBullet: hasBullet))
            }

            guard !candidates.isEmpty else { continue }

            // For bar chart fields, prefer bullet-prefixed values
            let toTry: [(text: String, centerX: Double, hasBullet: Bool)]
            if region.preferBullet {
                let bulleted = candidates.filter { $0.hasBullet }
                toTry = bulleted.isEmpty ? candidates : bulleted
            } else {
                toTry = candidates
            }

            // Extract the first valid numeric value
            for candidate in toTry {
                let cleaned = candidate.text.replacingOccurrences(
                    of: #"^[=•\-·mш\s]*"#, with: "", options: .regularExpression
                )
                if let value = parseNumericValue(cleaned) {
                    // For segmental fat, parse "X.Xlbs) | Y.Y%" pattern
                    if region.key.hasSuffix("FatPct"), let pct = parseSegmentalFatPct(candidate.text) {
                        setField(region.key, value: pct, on: &result)
                        #if DEBUG
                        print("[Position] \(region.key) = \(pct) (fat%)")
                        #endif
                    } else if region.key.hasSuffix("FatKg"), let kg = parseSegmentalFatKg(candidate.text) {
                        setField(region.key, value: kg, on: &result)
                        #if DEBUG
                        print("[Position] \(region.key) = \(kg) (fatKg)")
                        #endif
                    } else {
                        setField(region.key, value: value, on: &result)
                        #if DEBUG
                        print("[Position] \(region.key) = \(value)")
                        #endif
                    }
                    break
                }
            }
        }
    }

    /// Parses "X.Xlbs) | Y.Y%" or "X.Xlbs) - Y.Y%" to extract the percentage.
    private static func parseSegmentalFatPct(_ text: String) -> Double? {
        let pattern = #"[\|\-]\s*(\d+\.?\d*)\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    /// Parses "X.Xlbs)" to extract the kg/lbs value.
    private static func parseSegmentalFatKg(_ text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)\s*[Il|]?bs\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
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
            (#"(\d{2})\.\s*(\d{2})\.\s*(\d{4})"#, [1, 2, 3]),
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

    // MARK: - Field Access by Key

    /// Sets a field on InBodyParseResult by string key. No-ops for unknown keys.
    static func setField(_ key: String, value: Double, on result: inout InBodyParseResult) {
        switch key {
        case "weightKg":               result.weightKg = value
        case "skeletalMuscleMassKg":   result.skeletalMuscleMassKg = value
        case "bodyFatMassKg":          result.bodyFatMassKg = value
        case "bodyFatPct":             result.bodyFatPct = value
        case "totalBodyWaterL":        result.totalBodyWaterL = value
        case "bmi":                    result.bmi = value
        case "basalMetabolicRate":     result.basalMetabolicRate = value
        case "intracellularWaterL":    result.intracellularWaterL = value
        case "extracellularWaterL":    result.extracellularWaterL = value
        case "dryLeanMassKg":          result.dryLeanMassKg = value
        case "leanBodyMassKg":         result.leanBodyMassKg = value
        case "inBodyScore":            result.inBodyScore = value
        case "rightArmLeanKg":         result.rightArmLeanKg = value
        case "leftArmLeanKg":          result.leftArmLeanKg = value
        case "trunkLeanKg":            result.trunkLeanKg = value
        case "rightLegLeanKg":         result.rightLegLeanKg = value
        case "leftLegLeanKg":          result.leftLegLeanKg = value
        case "rightArmFatKg":          result.rightArmFatKg = value
        case "leftArmFatKg":           result.leftArmFatKg = value
        case "trunkFatKg":             result.trunkFatKg = value
        case "rightLegFatKg":          result.rightLegFatKg = value
        case "leftLegFatKg":           result.leftLegFatKg = value
        case "ecwTbwRatio":            result.ecwTbwRatio = value
        case "skeletalMuscleIndex":    result.skeletalMuscleIndex = value
        case "visceralFatLevel":       result.visceralFatLevel = value
        case "rightArmLeanPct":        result.rightArmLeanPct = value
        case "leftArmLeanPct":         result.leftArmLeanPct = value
        case "trunkLeanPct":           result.trunkLeanPct = value
        case "rightLegLeanPct":        result.rightLegLeanPct = value
        case "leftLegLeanPct":         result.leftLegLeanPct = value
        case "rightArmFatPct":         result.rightArmFatPct = value
        case "leftArmFatPct":          result.leftArmFatPct = value
        case "trunkFatPct":            result.trunkFatPct = value
        case "rightLegFatPct":         result.rightLegFatPct = value
        case "leftLegFatPct":          result.leftLegFatPct = value
        default: break
        }
    }

    /// Gets a field from InBodyParseResult by string key. Returns nil for unknown keys.
    static func getField(_ key: String, from result: InBodyParseResult) -> Double? {
        switch key {
        case "weightKg":               return result.weightKg
        case "skeletalMuscleMassKg":   return result.skeletalMuscleMassKg
        case "bodyFatMassKg":          return result.bodyFatMassKg
        case "bodyFatPct":             return result.bodyFatPct
        case "totalBodyWaterL":        return result.totalBodyWaterL
        case "bmi":                    return result.bmi
        case "basalMetabolicRate":     return result.basalMetabolicRate
        case "intracellularWaterL":    return result.intracellularWaterL
        case "extracellularWaterL":    return result.extracellularWaterL
        case "dryLeanMassKg":          return result.dryLeanMassKg
        case "leanBodyMassKg":         return result.leanBodyMassKg
        case "inBodyScore":            return result.inBodyScore
        case "rightArmLeanKg":         return result.rightArmLeanKg
        case "leftArmLeanKg":          return result.leftArmLeanKg
        case "trunkLeanKg":            return result.trunkLeanKg
        case "rightLegLeanKg":         return result.rightLegLeanKg
        case "leftLegLeanKg":          return result.leftLegLeanKg
        case "rightArmFatKg":          return result.rightArmFatKg
        case "leftArmFatKg":           return result.leftArmFatKg
        case "trunkFatKg":             return result.trunkFatKg
        case "rightLegFatKg":          return result.rightLegFatKg
        case "leftLegFatKg":           return result.leftLegFatKg
        case "ecwTbwRatio":            return result.ecwTbwRatio
        case "skeletalMuscleIndex":    return result.skeletalMuscleIndex
        case "visceralFatLevel":       return result.visceralFatLevel
        case "rightArmLeanPct":        return result.rightArmLeanPct
        case "leftArmLeanPct":         return result.leftArmLeanPct
        case "trunkLeanPct":           return result.trunkLeanPct
        case "rightLegLeanPct":        return result.rightLegLeanPct
        case "leftLegLeanPct":         return result.leftLegLeanPct
        case "rightArmFatPct":         return result.rightArmFatPct
        case "leftArmFatPct":          return result.leftArmFatPct
        case "trunkFatPct":            return result.trunkFatPct
        case "rightLegFatPct":         return result.rightLegFatPct
        case "leftLegFatPct":          return result.leftLegFatPct
        default:                       return nil
        }
    }

    // MARK: - Private Helpers

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
