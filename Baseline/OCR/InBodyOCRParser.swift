import Foundation
import Vision
import UIKit

/// OCR pipeline for InBody 570 result sheets.
///
/// Uses full-page OCR with pattern-based text parsing. Region-based extraction
/// can be added later once region coordinates are calibrated against real sheets.
enum InBodyOCRParser {

    private static let lbsToKg: Double = 0.45359237

    /// Full pipeline: process a captured image and return parsed results with confidence.
    static func processImage(_ image: UIImage) async -> InBodyParseResult {
        let textResult = await recognizeTextWithConfidence(from: image)
        let text = textResult.text
        let confidence = textResult.avgConfidence

        #if DEBUG
        print("=== FULL PAGE OCR ===")
        print(text)
        print("=== END FULL PAGE ===")
        #endif

        var result = parseFullPage(text)
        result.detectedUnit = detectUnit(from: text)

        // Apply confidence to all extracted fields
        applyConfidence(to: &result, confidence: confidence)

        #if DEBUG
        print("=== PARSED FIELDS ===")
        print("weightKg: \(result.weightKg as Any)")
        print("bodyFatPct: \(result.bodyFatPct as Any)")
        print("bmi: \(result.bmi as Any)")
        print("smm: \(result.skeletalMuscleMassKg as Any)")
        print("bmr: \(result.basalMetabolicRate as Any)")
        print("smi: \(result.skeletalMuscleIndex as Any)")
        print("ecwTbw: \(result.ecwTbwRatio as Any)")
        print("visceralFat: \(result.visceralFatLevel as Any)")
        print("bodyFatMass: \(result.bodyFatMassKg as Any)")
        print("scanDate: \(result.scanDate as Any)")
        print("=== END PARSED ===")
        #endif

        return result
    }

    // MARK: - Full Page Parser

    static func parseFullPage(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text
        let lines = text.components(separatedBy: .newlines)

        // === Date ===
        // Pattern: "MM. DD. YYYY" or "MM. DD.YYYY"
        let datePattern = #"(\d{2})\.\s*(\d{2})\.\s*(\d{4})\s+\d{2}:\d{2}"#
        if let dateMatch = firstMatch(datePattern, in: text) {
            let parts = dateMatch.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if parts.count >= 3, let m = Int(parts[0]), let d = Int(parts[1]), let y = Int(parts[2]) {
                var comp = DateComponents()
                comp.month = m; comp.day = d; comp.year = y
                result.scanDate = Calendar.current.date(from: comp)
            }
        }

        // === BMR ===
        // Pattern: number followed by "kcal"
        if let bmrMatch = firstMatch(#"(\d{3,4})\s*kcal"#, in: text) {
            let nums = extractAllNumbers(from: bmrMatch)
            if let val = nums.first, val > 1000 && val < 5000 {
                result.basalMetabolicRate = val
            }
        }

        // === SMI ===
        // Pattern: number followed by "kg/m"
        if let smiMatch = firstMatch(#"(\d+\.?\d*)\s*kg/m"#, in: text) {
            let nums = extractAllNumbers(from: smiMatch)
            if let val = nums.first, val > 3 && val < 20 {
                result.skeletalMuscleIndex = val
            }
        }

        // === ECW/TBW ===
        // Look for a 0.3xx value near ECW/TBW text
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("ecw/t") || lower.contains("ecw/tbw") {
                // Search this line and nearby lines for the ratio
                let searchRange = lines[max(0, i-2)...min(lines.count-1, i+3)]
                for searchLine in searchRange {
                    if let ratioMatch = firstMatch(#"0\.\s*3\d\d"#, in: searchLine) {
                        let cleaned = ratioMatch.replacingOccurrences(of: " ", with: "")
                        if let val = Double(cleaned), val > 0.3 && val < 0.5 {
                            result.ecwTbwRatio = val
                            break
                        }
                    }
                }
                if result.ecwTbwRatio != nil { break }
            }
        }

        // === Visceral Fat Level ===
        // Pattern: "Level N" near "Visceral"
        if let levelMatch = firstMatch(#"Level\s+(\d{1,2})"#, in: text) {
            let nums = extractAllNumbers(from: levelMatch)
            if let val = nums.first, val >= 1 && val <= 20 {
                result.visceralFatLevel = val
            }
        }

        // === Weight, SMM, Body Fat Mass (from Muscle-Fat Analysis) ===
        // The Muscle-Fat section has "Weight ... 197.2", "SMM ... 105.8", "Body Fat Mass ... 14.2"
        // We look for the pattern: label on one line, value nearby
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Weight — find the value on the SAME line or the line right after the Muscle-Fat Weight
            if lower == "weight" || (lower.contains("weight") && !lower.contains("body") && !lower.contains("water") && !lower.contains("current") && !lower.contains("ideal")) {
                // Look at nearby lines for a 3-digit number (weight in lbs: 100-400)
                for j in max(0, i-1)...min(lines.count-1, i+3) {
                    let nums = extractAllNumbers(from: lines[j])
                    for num in nums {
                        if num > 100 && num < 400 && result.weightKg == nil {
                            result.weightKg = num * lbsToKg
                        }
                    }
                }
            }
        }

        // === SMM (Skeletal Muscle Mass) ===
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("smm") || lower == "skeletal muscle mass" {
                for j in max(0, i-1)...min(lines.count-1, i+3) {
                    let nums = extractAllNumbers(from: lines[j])
                    for num in nums {
                        if num > 50 && num < 200 && result.skeletalMuscleMassKg == nil {
                            result.skeletalMuscleMassKg = num * lbsToKg
                        }
                    }
                }
            }
        }

        // === Body Fat Mass ===
        // Appears multiple times — look for it near "Body Fat Mass" label
        // The value 14.2 appears after "Body Fat Mass"
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("body fat mass") && !lower.contains("control") && !lower.contains("lean") {
                for j in i...min(lines.count-1, i+3) {
                    let nums = extractAllNumbers(from: lines[j])
                    for num in nums {
                        if num > 1 && num < 100 && result.bodyFatMassKg == nil {
                            result.bodyFatMassKg = num * lbsToKg
                        }
                    }
                }
                if result.bodyFatMassKg != nil { break }
            }
        }

        // === BMI ===
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("bmi") || lower.contains("body mass index") {
                for j in max(0, i-2)...min(lines.count-1, i+3) {
                    let nums = extractAllNumbers(from: lines[j])
                    for num in nums {
                        if num > 15 && num < 50 && result.bmi == nil {
                            result.bmi = num
                        }
                    }
                }
                if result.bmi != nil { break }
            }
        }

        // === PBF (Percent Body Fat) ===
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("pbf") || lower.contains("percent body fat") {
                for j in max(0, i-2)...min(lines.count-1, i+3) {
                    let nums = extractAllNumbers(from: lines[j])
                    for num in nums {
                        if num > 3 && num < 60 && result.bodyFatPct == nil {
                            result.bodyFatPct = num
                        }
                    }
                }
                if result.bodyFatPct != nil { break }
            }
        }

        // === Total Body Water, Lean Body Mass ===
        // Pattern in header area: "Total Body Water Lean Body Mass" then values "134.0 183.0"
        if let tbwIdx = lines.firstIndex(where: { $0.lowercased().contains("total body water") }) {
            // Values typically appear within a few lines
            for j in tbwIdx...min(lines.count-1, tbwIdx + 5) {
                let nums = extractAllNumbers(from: lines[j])
                if nums.count >= 2 {
                    // TBW is typically the larger of the pair if one looks like water volume
                    for num in nums {
                        if num > 20 && num < 80 && result.totalBodyWaterL == nil {
                            result.totalBodyWaterL = num // liters, no conversion
                        } else if num > 100 && num < 250 && result.leanBodyMassKg == nil {
                            result.leanBodyMassKg = num * lbsToKg
                        }
                    }
                }
            }
        }

        // === Intracellular Water ===
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("intracellular") {
                for j in i...min(lines.count-1, i+2) {
                    if let num = extractLastNumber(from: lines[j]), num > 10 && num < 60 {
                        result.intracellularWaterL = num // liters
                        break
                    }
                }
                if result.intracellularWaterL != nil { break }
            }
        }

        // === Extracellular Water ===
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("extracellular") && !lower.contains("ecw/") {
                for j in i...min(lines.count-1, i+2) {
                    if let num = extractLastNumber(from: lines[j]), num > 10 && num < 40 {
                        result.extracellularWaterL = num // liters
                        break
                    }
                }
                if result.extracellularWaterL != nil { break }
            }
        }

        // === Dry Lean Mass ===
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("dry lean") {
                for j in i...min(lines.count-1, i+2) {
                    if let num = extractLastNumber(from: lines[j]), num > 20 && num < 120 {
                        result.dryLeanMassKg = num * lbsToKg
                        break
                    }
                }
                if result.dryLeanMassKg != nil { break }
            }
        }

        // === Segmental Fat Analysis ===
        // Pattern: "0. 21bs) / 14. 4%" or "0. 21bs) - 14.4%"
        // OCR output: "0. 21bs) / 14.4%"  for right arm
        parseSegmentalFatFromFullText(lines: lines, result: &result)

        // === Segmental Lean Analysis ===
        parseSegmentalLeanFromFullText(lines: lines, result: &result)

        return result
    }

    // MARK: - Segmental Fat Parser

    private static func parseSegmentalFatFromFullText(lines: [String], result: inout InBodyParseResult) {
        // Find "Segmental Fat Analysis" section
        guard let startIdx = lines.firstIndex(where: { $0.lowercased().contains("segmental fat analysis") }) else { return }

        let segments = ["right arm", "left arm", "trunk", "right leg", "left leg"]
        var segmentIndex = 0

        for i in startIdx..<min(lines.count, startIdx + 20) {
            let lower = lines[i].lowercased()

            for (si, seg) in segments.enumerated() {
                if lower.contains(seg) && si >= segmentIndex {
                    segmentIndex = si + 1

                    // Extract mass and pct from this line
                    // Pattern: "0. 21bs) / 14. 4%" or "6. 81bs) -- 65. 7%"
                    let massPattern = #"(\d+\.?\s*\d*)\s*[Il1]bs?\)"#
                    let pctPattern = #"(\d+\.?\s*\d*)\s*%"#

                    var massVal: Double?
                    var pctVal: Double?

                    if let massMatch = firstMatch(massPattern, in: lines[i]) {
                        let cleaned = massMatch.replacingOccurrences(of: " ", with: "")
                        let nums = extractAllNumbers(from: cleaned)
                        massVal = nums.first
                    }
                    if let pctMatch = firstMatch(pctPattern, in: lines[i]) {
                        let cleaned = pctMatch.replacingOccurrences(of: " ", with: "")
                        let nums = extractAllNumbers(from: cleaned)
                        pctVal = nums.first
                    }

                    let massKg = massVal.map { $0 * lbsToKg }

                    switch seg {
                    case "right arm": result.rightArmFatKg = massKg; result.rightArmFatPct = pctVal
                    case "left arm": result.leftArmFatKg = massKg; result.leftArmFatPct = pctVal
                    case "trunk": result.trunkFatKg = massKg; result.trunkFatPct = pctVal
                    case "right leg": result.rightLegFatKg = massKg; result.rightLegFatPct = pctVal
                    case "left leg": result.leftLegFatKg = massKg; result.leftLegFatPct = pctVal
                    default: break
                    }
                    break
                }
            }
        }
    }

    // MARK: - Segmental Lean Parser

    private static func parseSegmentalLeanFromFullText(lines: [String], result: inout InBodyParseResult) {
        // Find "Segmental Lean Analysis" section
        guard let startIdx = lines.firstIndex(where: { $0.lowercased().contains("segmental lean analysis") }) else { return }

        // The segmental lean values appear as numbers in subsequent lines
        // From the OCR output, they appear mixed with bar chart values
        // Look for patterns like "Right Arm" followed by numbers and percentages
        let segments = ["right arm", "left arm", "trunk", "right leg", "left leg"]
        var segmentIndex = 0

        for i in startIdx..<min(lines.count, startIdx + 30) {
            let lower = lines[i].lowercased()

            for (si, seg) in segments.enumerated() {
                if lower.contains(seg) && si >= segmentIndex {
                    segmentIndex = si + 1

                    // Look at nearby lines for mass and pct values
                    // Lean mass is typically 3-120 lbs, pct is 80-180%
                    // This is harder to parse from full text — skip for now if we can't find clear patterns
                    break
                }
            }
        }
    }

    // MARK: - Unit Detection

    private static func detectUnit(from text: String) -> DetectedUnit {
        let lower = text.lowercased()
        // Check if values are labeled with "kg" units (vs "lbs"/"Ibs")
        if lower.contains("(kg)") || (lower.contains("kg") && !lower.contains("kg/m")) {
            return .kg
        }
        return .lbs
    }

    // MARK: - Confidence

    private static func applyConfidence(to result: inout InBodyParseResult, confidence: Float) {
        let fields: [(String, Double?)] = [
            ("weightKg", result.weightKg),
            ("skeletalMuscleMassKg", result.skeletalMuscleMassKg),
            ("bodyFatMassKg", result.bodyFatMassKg),
            ("bodyFatPct", result.bodyFatPct),
            ("totalBodyWaterL", result.totalBodyWaterL),
            ("bmi", result.bmi),
            ("basalMetabolicRate", result.basalMetabolicRate),
            ("intracellularWaterL", result.intracellularWaterL),
            ("extracellularWaterL", result.extracellularWaterL),
            ("dryLeanMassKg", result.dryLeanMassKg),
            ("leanBodyMassKg", result.leanBodyMassKg),
            ("inBodyScore", result.inBodyScore),
            ("ecwTbwRatio", result.ecwTbwRatio),
            ("skeletalMuscleIndex", result.skeletalMuscleIndex),
            ("visceralFatLevel", result.visceralFatLevel),
            ("rightArmFatKg", result.rightArmFatKg),
            ("leftArmFatKg", result.leftArmFatKg),
            ("trunkFatKg", result.trunkFatKg),
            ("rightLegFatKg", result.rightLegFatKg),
            ("leftLegFatKg", result.leftLegFatKg),
            ("rightArmFatPct", result.rightArmFatPct),
            ("leftArmFatPct", result.leftArmFatPct),
            ("trunkFatPct", result.trunkFatPct),
            ("rightLegFatPct", result.rightLegFatPct),
            ("leftLegFatPct", result.leftLegFatPct),
        ]
        for (key, value) in fields {
            if value != nil {
                result.confidence[key] = confidence
            }
        }
    }

    // MARK: - Vision OCR

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

    private static func recognizeText(from image: UIImage) async -> String {
        let result = await recognizeTextWithConfidence(from: image)
        return result.text
    }

    // MARK: - Helpers

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        guard let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }

    private static func extractLastNumber(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard let lastMatch = matches.last,
              let range = Range(lastMatch.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    private static func extractAllNumbers(from text: String) -> [Double] {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: cleaned) else { return nil }
            return Double(cleaned[range])
        }
    }
}
