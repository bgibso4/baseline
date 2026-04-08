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

    /// Calibrated regions for InBody 570 sheet fields.
    /// Coordinates from actual scan data (Vision bottom-left origin).
    ///
    /// Left column: x < 0.64.  Right column: x >= 0.64.
    static let fieldRegions: [FieldRegion] = [
        // --- Body Composition Analysis (tabular, tight X,Y boxes) ---
        // These values are in a fixed grid at the top of the left column.
        FieldRegion("intracellularWaterL",  y: 0.790...0.815, x: 0.20...0.30),
        FieldRegion("extracellularWaterL",  y: 0.760...0.785, x: 0.20...0.30),
        FieldRegion("totalBodyWaterL",      y: 0.775...0.800, x: 0.30...0.42),
        FieldRegion("dryLeanMassKg",        y: 0.735...0.760, x: 0.20...0.30),
        FieldRegion("leanBodyMassKg",       y: 0.755...0.785, x: 0.40...0.52),
        FieldRegion("weightKg",             y: 0.740...0.770, x: 0.50...0.62),
        FieldRegion("bodyFatMassKg",        y: 0.710...0.740, x: 0.20...0.30),

        // --- Muscle-Fat Analysis (bar charts — Y band, full left-column width, prefer bullet) ---
        FieldRegion("weightKg",             y: 0.635...0.670, x: 0.20...0.62, bullet: true),
        FieldRegion("skeletalMuscleMassKg", y: 0.605...0.640, x: 0.20...0.62, bullet: true),
        FieldRegion("bodyFatMassKg",        y: 0.575...0.610, x: 0.20...0.62, bullet: true),

        // --- Obesity Analysis (bar charts — prefer bullet) ---
        FieldRegion("bmi",                  y: 0.510...0.545, x: 0.20...0.62, bullet: true),
        FieldRegion("bodyFatPct",           y: 0.480...0.515, x: 0.20...0.62, bullet: true),

        // --- Segmental Lean Analysis (bar charts — prefer bullet for lbs values) ---
        FieldRegion("rightArmLeanKg",       y: 0.415...0.450, x: 0.35...0.55, bullet: true),
        FieldRegion("leftArmLeanKg",        y: 0.383...0.415, x: 0.35...0.55, bullet: true),
        FieldRegion("trunkLeanKg",          y: 0.350...0.383, x: 0.35...0.55, bullet: true),
        FieldRegion("rightLegLeanKg",       y: 0.318...0.350, x: 0.35...0.55, bullet: true),
        FieldRegion("leftLegLeanKg",        y: 0.285...0.318, x: 0.35...0.55, bullet: true),

        // --- Segmental Lean sufficiency % (to the right of the lean kg values) ---
        FieldRegion("rightArmLeanPct",      y: 0.415...0.450, x: 0.42...0.62),
        FieldRegion("leftArmLeanPct",       y: 0.383...0.415, x: 0.42...0.62),
        FieldRegion("trunkLeanPct",         y: 0.350...0.383, x: 0.42...0.62),
        FieldRegion("rightLegLeanPct",      y: 0.318...0.350, x: 0.42...0.62),
        FieldRegion("leftLegLeanPct",       y: 0.285...0.318, x: 0.42...0.62),

        // --- ECW/TBW Analysis (bar chart, prefer bullet) ---
        FieldRegion("ecwTbwRatio",          y: 0.220...0.260, x: 0.20...0.62, bullet: true),

        // --- Right column fields ---
        FieldRegion("basalMetabolicRate",   y: 0.595...0.630, x: 0.64...1.0),
        FieldRegion("skeletalMuscleIndex",  y: 0.520...0.555, x: 0.64...1.0),
        FieldRegion("visceralFatLevel",     y: 0.555...0.600, x: 0.64...0.78),

        // --- Segmental Fat (right column, pattern: "X.Xlbs) | Y.Y%") ---
        FieldRegion("rightArmFatKg",        y: 0.700...0.730, x: 0.64...1.0),
        FieldRegion("leftArmFatKg",         y: 0.685...0.705, x: 0.64...1.0),
        FieldRegion("trunkFatKg",           y: 0.665...0.690, x: 0.64...1.0),
        FieldRegion("rightLegFatKg",        y: 0.645...0.670, x: 0.64...1.0),
        FieldRegion("leftLegFatKg",         y: 0.630...0.655, x: 0.64...1.0),
        FieldRegion("rightArmFatPct",       y: 0.700...0.730, x: 0.64...1.0),
        FieldRegion("leftArmFatPct",        y: 0.685...0.705, x: 0.64...1.0),
        FieldRegion("trunkFatPct",          y: 0.665...0.690, x: 0.64...1.0),
        FieldRegion("rightLegFatPct",       y: 0.645...0.670, x: 0.64...1.0),
        FieldRegion("leftLegFatPct",        y: 0.630...0.655, x: 0.64...1.0),
    ]

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

        for region in fieldRegions {
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
    /// Handles: "89.5 kg", "17.1%", "1842 kcal", "0.380", plain integers.
    static func parseNumericValue(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Extract the first number using regex (handles embedded units)
        let pattern = #"-?\d+\.?\d*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let range = Range(match.range, in: trimmed)
        else { return nil }

        return Double(trimmed[range])
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
