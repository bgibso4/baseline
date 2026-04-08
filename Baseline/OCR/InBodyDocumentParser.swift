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

            extractFromTables(doc.tables, into: &result, confidence: confidence)
            extractFromParagraphs(doc.paragraphs, into: &result, confidence: confidence)
            extractDate(from: doc, into: &result)

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

    /// Fallback: scans paragraphs for "Label: Value" or "Label Value" patterns.
    static func extractFromParagraphs(
        _ paragraphs: [DocumentObservation.Container.Text],
        into result: inout InBodyParseResult,
        confidence: Float
    ) {
        for paragraph in paragraphs {
            let text = paragraph.transcript
            #if DEBUG
            print("[InBodyDocumentParser] Paragraph: \(text.prefix(80))")
            #endif

            // Pattern 1: "Label: Value" (colon separator)
            if let colonRange = text.range(of: ":") {
                let labelPart = String(text[text.startIndex..<colonRange.lowerBound])
                let valuePart = String(text[colonRange.upperBound...])
                if let key = fieldKey(for: labelPart),
                   getField(key, from: result) == nil,
                   let value = parseNumericValue(valuePart) {
                    setField(key, value: value, on: &result)
                    if confidence > 0 {
                        result.confidence[key] = confidence
                    }
                    #if DEBUG
                    print("[InBodyDocumentParser] Paragraph (colon) field: \(key) = \(value)")
                    #endif
                    continue
                }
            }

            // Pattern 2: "Label Value" (whitespace separator — last token is value)
            let parts = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }

            // Try progressively shorter label candidates from the left, leaving at least one token for value
            for splitIndex in stride(from: parts.count - 1, through: 1, by: -1) {
                let labelCandidate = parts[0..<splitIndex].joined(separator: " ")
                let valueCandidate = parts[splitIndex...].joined(separator: " ")
                if let key = fieldKey(for: labelCandidate),
                   getField(key, from: result) == nil,
                   let value = parseNumericValue(valueCandidate) {
                    setField(key, value: value, on: &result)
                    if confidence > 0 {
                        result.confidence[key] = confidence
                    }
                    #if DEBUG
                    print("[InBodyDocumentParser] Paragraph (space) field: \(key) = \(value)")
                    #endif
                    break
                }
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
