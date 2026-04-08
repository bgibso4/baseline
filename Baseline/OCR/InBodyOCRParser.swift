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
        // Pattern: number followed by "kg/m" — OCR may insert spaces in number ("10. 4 kg/m")
        if let smiMatch = firstMatch(#"(\d+\.?\s*\d+)\s*kg/m"#, in: text) {
            let cleaned = smiMatch.replacingOccurrences(of: " ", with: "")
            let nums = extractAllNumbers(from: cleaned)
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
        // In Body Composition History: "105.8" appears on its own line near "SMM"
        // In Muscle-Fat section: "SMM" label appears but value is mixed with bar chart
        // Strategy: search wider window, prefer numbers in 60-180 lbs range
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("smm") || lower.contains("skeletal muscle mas") {
                // Search nearby lines (wider window)
                for j in max(0, i-3)...min(lines.count-1, i+3) {
                    let cleaned = lines[j].replacingOccurrences(of: " ", with: "")
                    let nums = extractAllNumbers(from: cleaned)
                    for num in nums {
                        if num > 60 && num < 180 && result.skeletalMuscleMassKg == nil {
                            result.skeletalMuscleMassKg = num * lbsToKg
                        }
                    }
                }
                if result.skeletalMuscleMassKg != nil { break }
            }
        }

        // === Body Fat Mass ===
        // In the Muscle-Fat section, appears as "Body Fat Mass (Ibs)" then "*14. 2" on nearby line
        // Also appears as "14.2" at end of the body comp values block
        // Strategy: look for "body fat mass" with "(lbs)" or "(Ibs)" on same/nearby line (Muscle-Fat section)
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("body fat mass") && (lower.contains("lbs") || lower.contains("ibs")) && !lower.contains("control") {
                // Check this line and next few for a number in plausible range (1-80 lbs)
                for j in i...min(lines.count-1, i+2) {
                    // Clean OCR artifacts like "*14. 2" → "14.2"
                    let cleaned = lines[j].replacingOccurrences(of: "*", with: "").replacingOccurrences(of: " ", with: "")
                    let nums = extractAllNumbers(from: cleaned)
                    for num in nums {
                        if num > 1 && num < 80 && result.bodyFatMassKg == nil {
                            result.bodyFatMassKg = num * lbsToKg
                        }
                    }
                }
                if result.bodyFatMassKg != nil { break }
            }
        }
        // Fallback: if not found in Muscle-Fat section, look for standalone "14.2" after body comp values
        if result.bodyFatMassKg == nil {
            for (i, line) in lines.enumerated() {
                let lower = line.lowercased()
                if lower.contains("body fat mass") && !lower.contains("control") && !lower.contains("lean") {
                    // Search forward for a small number (body fat mass in lbs: typically 5-60)
                    for j in i...min(lines.count-1, i+8) {
                        let nums = extractAllNumbers(from: lines[j])
                        for num in nums {
                            if num > 3 && num < 60 && result.bodyFatMassKg == nil {
                                result.bodyFatMassKg = num * lbsToKg
                            }
                        }
                    }
                    if result.bodyFatMassKg != nil { break }
                }
            }
        }

        // === BMI ===
        // BMI value often gets lost in bar chart numbers. Try multiple strategies:
        // 1. Look for a number 15-50 near "BMI" label
        // 2. Look near "Obesity Analysis" section
        // 3. Look in Body Composition History values
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("bmi") && !lower.contains("smm") && !lower.contains("analysis") {
                // Check this line first
                let sameLineNums = extractAllNumbers(from: line)
                for num in sameLineNums {
                    if num > 15 && num < 50 && result.bmi == nil {
                        result.bmi = num
                    }
                }
                if result.bmi != nil { break }
                // Check nearby lines
                for j in max(0, i-2)...min(lines.count-1, i+5) {
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
        // Fallback: calculate from weight and height if we have weight
        // BMI = weight(kg) / height(m)^2 — but we'd need height from the scan

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

        // === Body Composition Values Block ===
        // The InBody 570 OCR reads labels first, then values as a block:
        //   Labels: Intracellular Water, Extracellular Water, Dry Lean Mass, Body Fat Mass
        //   Values: 84.7, 134.0, 49.4, 183.0, 48.9, 14.2
        //   Where: ICW=84.7, TBW=134.0, ECW=49.4, LBM=183.0, DryLean=48.9, BFM=14.2
        // Also: "Total Body Water Lean Body Mass" header shows TBW and LBM column values
        //
        // Strategy: find the body comp section, collect the value block, assign by position
        if let bodyCompIdx = lines.firstIndex(where: { $0.lowercased().contains("body composition analysis") }) {
            // Find "Muscle-Fat Analysis" to mark the end of body comp section
            let endIdx = lines[bodyCompIdx...].firstIndex(where: { $0.lowercased().contains("muscle-fat") }) ?? bodyCompIdx + 20

            // Collect all numbers between body comp and muscle-fat headers
            var values: [Double] = []
            for j in bodyCompIdx...min(lines.count-1, endIdx + 5) {
                let cleaned = lines[j].replacingOccurrences(of: " ", with: "")
                let nums = extractAllNumbers(from: cleaned)
                for num in nums {
                    if num > 5 && num < 250 { // plausible body comp values in lbs
                        values.append(num)
                    }
                }
            }

            // From the OCR output pattern, the values appear as:
            // [84.7, 134.0, 49.4, 183.0, 48.9, 14.2]
            // = [ICW, TBW, ECW, LBM, DryLean, BFM]
            // But order may vary — use heuristics based on value ranges:
            // ICW: 50-110 lbs (largest water component)
            // ECW: 30-70 lbs (smaller water component)
            // TBW: 100-170 lbs (ICW + ECW)
            // LBM: 130-250 lbs (lean body mass, largest value)
            // DryLean: 30-80 lbs (LBM - TBW)
            // BFM: 5-60 lbs (body fat mass, typically smallest)

            // Sort values to identify them by magnitude
            let sorted = values.sorted()
            if sorted.count >= 6 {
                // Assign by expected magnitude ordering
                let bfm = sorted[0]      // smallest: body fat mass
                let dryLean = sorted[1]   // next: dry lean mass or ECW
                let ecw = sorted[2]       // next: ECW
                let icw = sorted[3]       // next: ICW
                let tbw = sorted[4]       // next: TBW
                let lbm = sorted[5]       // largest: lean body mass

                if bfm < 60 { result.bodyFatMassKg = result.bodyFatMassKg ?? (bfm * lbsToKg) }
                if ecw > 30 && ecw < 70 { result.extracellularWaterL = ecw * lbsToKg }
                if dryLean > 25 && dryLean < 80 { result.dryLeanMassKg = dryLean * lbsToKg }
                if icw > 50 && icw < 120 { result.intracellularWaterL = icw * lbsToKg }
                if tbw > 100 && tbw < 170 { result.totalBodyWaterL = tbw * lbsToKg }
                if lbm > 130 { result.leanBodyMassKg = lbm * lbsToKg }
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
