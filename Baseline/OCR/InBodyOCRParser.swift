import Foundation
import Vision
import UIKit

/// OCR pipeline for InBody 570 result sheets.
///
/// Uses full-page OCR with pattern-based text parsing. Key insight: actual values
/// on the InBody 570 are prefixed with bullet markers (•, -, ·) while bar chart
/// tick marks are bare numbers.
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
        applyConfidence(to: &result, confidence: confidence)

        #if DEBUG
        let fields: [(String, Any?)] = [
            ("weightKg", result.weightKg), ("bodyFatPct", result.bodyFatPct),
            ("bmi", result.bmi), ("smm", result.skeletalMuscleMassKg),
            ("bmr", result.basalMetabolicRate), ("smi", result.skeletalMuscleIndex),
            ("ecwTbw", result.ecwTbwRatio), ("visceralFat", result.visceralFatLevel),
            ("bodyFatMass", result.bodyFatMassKg), ("scanDate", result.scanDate),
            ("icw", result.intracellularWaterL), ("ecw", result.extracellularWaterL),
            ("tbw", result.totalBodyWaterL), ("lbm", result.leanBodyMassKg),
            ("dryLean", result.dryLeanMassKg),
        ]
        print("=== PARSED FIELDS ===")
        for (name, val) in fields { print("\(name): \(val as Any)") }
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
        // Pattern: "MM. DD. YYYY HH:MM" or "MM. DD.YYYY HH:MM" (OCR varies spacing)
        // Also handle colon-as-dot: "03. 19.2026 07:37"
        let datePatterns = [
            #"(\d{2})\.\s*(\d{2})\.\s*(\d{4})\s+\d{2}:\d{2}"#,  // "03. 19. 2026 07:37"
            #"(\d{2})\.\s*(\d{2})\.(\d{4})\s+\d{2}:\d{2}"#,      // "03. 19.2026 07:37"
            #"(\d{2})\.\s*(\d{2})\.\s*(\d{4})"#,                  // "03. 19. 2026" (no time)
        ]
        for pattern in datePatterns {
            if result.scanDate != nil { break }
            if let dateMatch = firstMatch(pattern, in: text) {
                let nums = extractAllNumbers(from: dateMatch)
                if nums.count >= 3 {
                    let m = Int(exactly: nums[0]) ?? 0
                    let d = Int(exactly: nums[1]) ?? 0
                    let y: Int
                    // Handle case where day.year run together: nums might be [3, 19.2026]
                    // or correctly split as [3, 19, 2026]
                    if nums[2] > 2000 {
                        y = Int(exactly: nums[2]) ?? 0
                    } else if nums.count >= 4 && nums[3] > 2000 {
                        y = Int(exactly: nums[3]) ?? 0
                    } else {
                        continue
                    }
                    if m > 0 && m <= 12 && d > 0 && d <= 31 && y > 2020 {
                        var comp = DateComponents()
                        comp.month = m; comp.day = d; comp.year = y
                        result.scanDate = Calendar.current.date(from: comp)
                    }
                }
            }
        }

        // === BMR ===
        // Reliable pattern: "NNNN kcal"
        if let bmrMatch = firstMatch(#"(\d{3,4})\s*kcal"#, in: text) {
            let nums = extractAllNumbers(from: bmrMatch)
            if let val = nums.first, val > 1000 && val < 5000 {
                result.basalMetabolicRate = val
            }
        }

        // === SMI ===
        // Pattern: "NN.N kg/m" (OCR may add spaces: "10. 4 kg/m")
        if let smiMatch = firstMatch(#"(\d+\.?\s*\d+)\s*kg/m"#, in: text) {
            let cleaned = smiMatch.replacingOccurrences(of: " ", with: "")
            let nums = extractAllNumbers(from: cleaned)
            if let val = nums.first, val > 3 && val < 20 {
                result.skeletalMuscleIndex = val
            }
        }

        // === Visceral Fat Level ===
        // Pattern: "Level N" or standalone number near "Visceral Fat Level" label
        if let levelMatch = firstMatch(#"Level\s+(\d{1,2})"#, in: text) {
            let nums = extractAllNumbers(from: levelMatch)
            if let val = nums.first, val >= 1 && val <= 20 {
                result.visceralFatLevel = val
            }
        }
        // Fallback: look for a small number (1-20) near "Visceral Fat Level" label
        if result.visceralFatLevel == nil {
            for (i, line) in lines.enumerated() {
                if line.lowercased().contains("visceral fat level") {
                    for j in max(0, i-1)...min(lines.count-1, i+4) {
                        let cleaned = lines[j].replacingOccurrences(of: " ", with: "")
                        if let num = Double(cleaned), num >= 1 && num <= 20 {
                            result.visceralFatLevel = num
                            break
                        }
                    }
                    if result.visceralFatLevel != nil { break }
                }
            }
        }

        // === Body Composition Values (positional) ===
        // OCR reads labels first, then values as a block:
        //   84.7, 49.4, 48.9, 14.2  (ICW, ECW, DryLean, BFM)
        //   134.0, 183.0             (TBW, LBM — from header columns)
        parseBodyCompBlock(lines: lines, result: &result)

        // === Muscle-Fat Analysis (bullet-marked values) ===
        // Actual values have bullet markers: "• 197.2", "- 105.8", "14. 2"
        parseMuscleFatSection(lines: lines, result: &result)

        // === Obesity Analysis (bullet-marked values) ===
        // BMI: "• 26. 0", PBF from history section
        parseObesitySection(lines: lines, result: &result)

        // === PBF (Percent Body Fat) ===
        // Look for bullet-marked value in Obesity section, or near PBF label
        parsePBF(lines: lines, result: &result)

        // === ECW/TBW ===
        // The actual ratio has a marker, tick marks don't: "ша 0. 369" vs "0.390 0.400 0.410..."
        parseEcwTbwRatio(lines: lines, result: &result)

        // === Segmental Fat Analysis ===
        parseSegmentalFat(lines: lines, result: &result)

        // === Segmental Lean Analysis ===
        parseSegmentalLean(lines: lines, result: &result)

        return result
    }

    // MARK: - Body Composition Block

    private static func parseBodyCompBlock(lines: [String], result: inout InBodyParseResult) {
        // Find body comp section
        guard let startIdx = lines.firstIndex(where: { $0.lowercased().contains("body composition analysis") }) else { return }

        // DON'T stop at "Muscle-Fat Analysis" — OCR reads labels first (left column),
        // then "Muscle-Fat Analysis" header, THEN the values (right column).
        // Instead, look for "Obesity Analysis" or "SMM" as the end boundary.
        let endIdx = lines[startIdx...].firstIndex(where: { $0.lowercased().contains("obesity analysis") }) ?? startIdx + 30

        // Collect standalone numbers (lines that are JUST a number)
        var values: [Double] = []
        for j in (startIdx + 1)..<min(lines.count, endIdx) {
            let trimmed = lines[j].trimmingCharacters(in: .whitespaces)
            let cleaned = trimmed.replacingOccurrences(of: " ", with: "")
            if let num = Double(cleaned), num > 5 && num < 250 {
                values.append(num)
            }
        }

        // OCR reads values as: [84.7, 134.0, 49.4, 48.9, 14.2, 183.0, 197.2]
        // Split into: small values (<100) = field measurements, large values (>=100) = column totals
        // Small values appear in order: ICW, ECW, DryLean, BFM
        // Large values: TBW (~130), LBM (~180), Weight (~190+)
        let small = values.filter { $0 < 100 }  // field values
        let large = values.filter { $0 >= 100 }  // column totals

        // Assign small values positionally: ICW, ECW, DryLean, BFM
        if small.count >= 1 { result.intracellularWaterL = small[0] * lbsToKg }
        if small.count >= 2 { result.extracellularWaterL = small[1] * lbsToKg }
        if small.count >= 3 { result.dryLeanMassKg = small[2] * lbsToKg }
        if small.count >= 4 { result.bodyFatMassKg = small[3] * lbsToKg }

        // Assign large values by magnitude
        for val in large {
            if val > 100 && val < 170 && result.totalBodyWaterL == nil {
                result.totalBodyWaterL = val * lbsToKg
            } else if val >= 170 && val < 210 && result.leanBodyMassKg == nil {
                result.leanBodyMassKg = val * lbsToKg
            }
            // Weight (>190) is already captured from Muscle-Fat section
        }
    }

    // MARK: - Muscle-Fat Section (bullet-marked)

    private static func parseMuscleFatSection(lines: [String], result: inout InBodyParseResult) {
        guard let startIdx = lines.firstIndex(where: { $0.lowercased().contains("muscle-fat analysis") }) else { return }
        let endIdx = lines[startIdx...].firstIndex(where: { $0.lowercased().contains("obesity analysis") }) ?? startIdx + 20

        for j in startIdx..<min(lines.count, endIdx) {
            let line = lines[j]

            // Look for bullet-marked values: "• 197.2", "- 105.8"
            // Bullets: •, -, ·, *, ▪
            if let markedValue = extractBulletMarkedNumber(from: line) {
                if markedValue > 150 && markedValue < 400 && result.weightKg == nil {
                    result.weightKg = markedValue * lbsToKg
                } else if markedValue > 60 && markedValue < 180 && result.skeletalMuscleMassKg == nil {
                    result.skeletalMuscleMassKg = markedValue * lbsToKg
                }
            }
        }

        // Fallback: if weight not found with bullet, use Body Comp History
        if result.weightKg == nil {
            for (i, line) in lines.enumerated() {
                if line.lowercased().contains("body composition history") {
                    for j in i..<min(lines.count, i + 8) {
                        let cleaned = lines[j].replacingOccurrences(of: " ", with: "")
                        if let num = Double(cleaned), num > 150 && num < 400 {
                            result.weightKg = num * lbsToKg
                            break
                        }
                    }
                    break
                }
            }
        }

        // Fallback for SMM: Body Comp History shows "105.8" clearly
        if result.skeletalMuscleMassKg == nil {
            for (i, line) in lines.enumerated() {
                let lower = line.lowercased()
                if lower == "smm" || lower.contains("skeletal muscle mas") {
                    // Check adjacent lines
                    for j in max(0, i-2)...min(lines.count-1, i+2) {
                        let cleaned = lines[j].replacingOccurrences(of: " ", with: "")
                        if let num = Double(cleaned), num > 60 && num < 180 {
                            result.skeletalMuscleMassKg = num * lbsToKg
                            break
                        }
                    }
                    if result.skeletalMuscleMassKg != nil { break }
                }
            }
        }
    }

    // MARK: - Obesity Section

    private static func parseObesitySection(lines: [String], result: inout InBodyParseResult) {
        guard let startIdx = lines.firstIndex(where: { $0.lowercased().contains("obesity analysis") }) else { return }
        let endIdx = lines[startIdx...].firstIndex(where: { $0.lowercased().contains("segmental lean") }) ?? startIdx + 15

        for j in startIdx..<min(lines.count, endIdx) {
            let line = lines[j]

            // Look for bullet-marked BMI: "• 26. 0"
            if let markedValue = extractBulletMarkedNumber(from: line) {
                if markedValue > 15 && markedValue < 45 && result.bmi == nil {
                    result.bmi = markedValue
                }
            }
        }

        // BMI fallback: look for "26.0" pattern near BMI label with OCR space cleaning
        if result.bmi == nil {
            for (i, line) in lines.enumerated() {
                if line.lowercased().contains("bmi") {
                    for j in max(0, i-1)...min(lines.count-1, i+5) {
                        // Clean OCR spaces: "26. 0" → "26.0"
                        let cleaned = lines[j]
                            .replacingOccurrences(of: ". ", with: ".")
                            .replacingOccurrences(of: " .", with: ".")
                        if let markedVal = extractBulletMarkedNumber(from: cleaned) {
                            if markedVal > 15 && markedVal < 45 {
                                result.bmi = markedVal
                                break
                            }
                        }
                    }
                    if result.bmi != nil { break }
                }
            }
        }
    }

    // MARK: - PBF from History Section (most reliable)

    private static func parsePBF(lines: [String], result: inout InBodyParseResult) {
        // Strategy 1: look for bullet-marked PBF in Obesity Analysis section
        // (same approach as BMI — bullet marks the actual value)
        if let obesityIdx = lines.firstIndex(where: { $0.lowercased().contains("obesity analysis") }) {
            let endIdx = lines[obesityIdx...].firstIndex(where: { $0.lowercased().contains("segmental") }) ?? obesityIdx + 15
            for j in obesityIdx..<min(lines.count, endIdx) {
                if let marked = extractBulletMarkedNumber(from: lines[j]) {
                    // PBF is typically 3-50%, BMI is 15-45 — PBF is usually the smaller one
                    // Only take it if we haven't already assigned BMI to this value
                    if marked > 3 && marked < 50 && marked != result.bmi {
                        result.bodyFatPct = marked
                        break
                    }
                }
            }
        }

        // Strategy 2: look near "PBF" or "Percent Body Fat" label (not in history)
        if result.bodyFatPct == nil {
            for (i, line) in lines.enumerated() {
                let lower = line.lowercased()
                if lower == "pbf" || lower.contains("percent body fat") {
                    // Skip if this is in the history section or results interpretation
                    let nearbyText = lines[max(0, i-3)...min(lines.count-1, i+1)].joined(separator: " ").lowercased()
                    if nearbyText.contains("history") || nearbyText.contains("interpretation") { continue }

                    for j in max(0, i-2)...min(lines.count-1, i+4) {
                        let cleaned = lines[j]
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: ":", with: ".")
                        if let num = Double(cleaned), num > 3 && num < 50 {
                            result.bodyFatPct = num
                            break
                        }
                    }
                    if result.bodyFatPct != nil { break }
                }
            }
        }
    }

    // MARK: - ECW/TBW Ratio

    private static func parseEcwTbwRatio(lines: [String], result: inout InBodyParseResult) {
        // Find "ECW/TBW Analysis" section (the chart, not history)
        guard let startIdx = lines.firstIndex(where: {
            let l = $0.lowercased()
            return l.contains("ecw/tbw analysis") || l.contains("ecw/tw analysis")
        }) else {
            // Fallback: find first "ECW/TBW" or "ECW/TW" that's NOT in history/interpretation
            for (i, line) in lines.enumerated() {
                let lower = line.lowercased()
                if (lower.contains("ecw/tbw") || lower.contains("ecw/tw")) &&
                   !lower.contains("history") && !lower.contains("ratio of") {
                    parseEcwTbwNearLine(i, lines: lines, result: &result)
                    if result.ecwTbwRatio != nil { return }
                }
            }
            return
        }

        parseEcwTbwNearLine(startIdx, lines: lines, result: &result)
    }

    private static func parseEcwTbwNearLine(_ lineIdx: Int, lines: [String], result: inout InBodyParseResult) {
        // Look for the actual ECW/TBW ratio value near this line.
        // Skip tick mark sequences like "0.390 0.400 0.410..."
        // Accept: "0. 369" (standalone), "в 0. 369" (bullet-marked)
        for j in max(0, lineIdx - 2)...min(lines.count - 1, lineIdx + 6) {
            let line = lines[j]
            let cleaned = line.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ":", with: ".")
            let allNums = extractAllNumbers(from: cleaned)
            let ratios = allNums.filter { $0 >= 0.3 && $0 < 0.5 }

            if ratios.count == 1 && allNums.count <= 2 {
                // Line has exactly 1 ratio and at most 1 other number — not a tick sequence
                result.ecwTbwRatio = ratios[0]
                return
            }
            // Skip lines with 3+ ratios (tick mark sequences)
        }
    }

    // MARK: - Segmental Fat

    private static func parseSegmentalFat(lines: [String], result: inout InBodyParseResult) {
        guard let startIdx = lines.firstIndex(where: { $0.lowercased().contains("segmental fat analysis") }) else { return }

        let segments: [(String, WritableKeyPath<InBodyParseResult, Double?>, WritableKeyPath<InBodyParseResult, Double?>)] = [
            ("right arm", \.rightArmFatKg, \.rightArmFatPct),
            ("left arm", \.leftArmFatKg, \.leftArmFatPct),
            ("trunk", \.trunkFatKg, \.trunkFatPct),
            ("right leg", \.rightLegFatKg, \.rightLegFatPct),
            ("left leg", \.leftLegFatKg, \.leftLegFatPct),
        ]

        for i in startIdx..<min(lines.count, startIdx + 20) {
            let lower = lines[i].lowercased()
            for (seg, massPath, pctPath) in segments {
                if lower.contains(seg) {
                    // Pattern: "X.Xlbs) | YY.Y%" or "X.Xlbs) - YY.Y%"
                    let cleaned = lines[i].replacingOccurrences(of: " ", with: "")
                    // Extract mass: number before "lbs)" or "Ibs)"
                    if let massMatch = firstMatch(#"(\d+\.?\d*)[Il1]bs?\)"#, in: cleaned) {
                        let nums = extractAllNumbers(from: massMatch)
                        if let mass = nums.first {
                            result[keyPath: massPath] = mass * lbsToKg
                        }
                    }
                    // Extract pct: number before "%"
                    if let pctMatch = firstMatch(#"(\d+\.?\d*)%"#, in: cleaned) {
                        let nums = extractAllNumbers(from: pctMatch)
                        if let pct = nums.first {
                            result[keyPath: pctPath] = pct
                        }
                    }
                    break
                }
            }
        }
    }

    // MARK: - Segmental Lean

    private static func parseSegmentalLean(lines: [String], result: inout InBodyParseResult) {
        guard let startIdx = lines.firstIndex(where: { $0.lowercased().contains("segmental lean analysis") }) else { return }
        let endIdx = lines[startIdx...].firstIndex(where: { $0.lowercased().contains("ecw/tbw") || $0.lowercased().contains("ecw/tw") }) ?? startIdx + 30

        // Segmental lean values are harder to extract from full text because they're
        // mixed with bar chart graphics. Look for bullet-marked values near segment names.
        let segments: [(String, WritableKeyPath<InBodyParseResult, Double?>, WritableKeyPath<InBodyParseResult, Double?>)] = [
            ("right arm", \.rightArmLeanKg, \.rightArmLeanPct),
            ("left arm", \.leftArmLeanKg, \.leftArmLeanPct),
            ("trunk", \.trunkLeanKg, \.trunkLeanPct),
            ("right leg", \.rightLegLeanKg, \.rightLegLeanPct),
            ("left leg", \.leftLegLeanKg, \.leftLegLeanPct),
        ]

        for i in startIdx..<min(lines.count, endIdx) {
            let lower = lines[i].lowercased()
            for (seg, massPath, pctPath) in segments {
                if lower.contains(seg) {
                    // Look at nearby lines for bullet-marked values
                    for j in max(startIdx, i-1)...min(lines.count-1, i+3) {
                        if let marked = extractBulletMarkedNumber(from: lines[j]) {
                            if marked > 3 && marked < 120 && result[keyPath: massPath] == nil {
                                result[keyPath: massPath] = marked * lbsToKg
                            } else if marked > 100 && marked < 200 && result[keyPath: pctPath] == nil {
                                result[keyPath: pctPath] = marked
                            }
                        }
                    }
                    break
                }
            }
        }
    }

    // MARK: - Bullet Marker Extraction

    /// Extract a number that's preceded by a bullet marker (•, -, ·, *, ▪, ша, etc.)
    /// These markers distinguish actual values from bar chart tick marks on InBody sheets.
    private static func extractBulletMarkedNumber(from text: String) -> Double? {
        // Pattern: bullet/marker character(s) followed by optional space then a number
        // Bullets seen in OCR: "•", "-", "·", "*", Unicode artifacts like "ша"
        let pattern = #"[•\-·*▪■]\s*(\d+\.?\s*\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let numStr = String(text[range]).replacingOccurrences(of: " ", with: "")
        return Double(numStr)
    }

    // MARK: - Unit Detection

    private static func detectUnit(from text: String) -> DetectedUnit {
        let lower = text.lowercased()
        if lower.contains("(kg)") { return .kg }
        return .lbs
    }

    // MARK: - Confidence

    private static func applyConfidence(to result: inout InBodyParseResult, confidence: Float) {
        let fields: [(String, Double?)] = [
            ("weightKg", result.weightKg), ("skeletalMuscleMassKg", result.skeletalMuscleMassKg),
            ("bodyFatMassKg", result.bodyFatMassKg), ("bodyFatPct", result.bodyFatPct),
            ("totalBodyWaterL", result.totalBodyWaterL), ("bmi", result.bmi),
            ("basalMetabolicRate", result.basalMetabolicRate),
            ("intracellularWaterL", result.intracellularWaterL),
            ("extracellularWaterL", result.extracellularWaterL),
            ("dryLeanMassKg", result.dryLeanMassKg), ("leanBodyMassKg", result.leanBodyMassKg),
            ("ecwTbwRatio", result.ecwTbwRatio), ("skeletalMuscleIndex", result.skeletalMuscleIndex),
            ("visceralFatLevel", result.visceralFatLevel),
            ("rightArmFatKg", result.rightArmFatKg), ("leftArmFatKg", result.leftArmFatKg),
            ("trunkFatKg", result.trunkFatKg), ("rightLegFatKg", result.rightLegFatKg),
            ("leftLegFatKg", result.leftLegFatKg),
            ("rightArmFatPct", result.rightArmFatPct), ("leftArmFatPct", result.leftArmFatPct),
            ("trunkFatPct", result.trunkFatPct), ("rightLegFatPct", result.rightLegFatPct),
            ("leftLegFatPct", result.leftLegFatPct),
        ]
        for (key, value) in fields {
            if value != nil { result.confidence[key] = confidence }
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
