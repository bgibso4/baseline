import Foundation

/// Per-region text parsers for the InBody 570 result sheet.
/// Each function takes OCR-recognized text from a specific region
/// and returns an InBodyParseResult with only its fields populated.
enum InBody570RegionParsers {

    private static let lbsToKg: Double = 0.45359237

    // MARK: - Unit Detection

    /// Checks if the text contains "kg" (case-insensitive). Defaults to .lbs.
    static func detectUnit(from text: String) -> DetectedUnit {
        text.range(of: "kg", options: .caseInsensitive) != nil ? .kg : .lbs
    }

    // MARK: - R1: Header

    /// Extracts scan date from header text.
    /// Expected format: "MM. DD. YYYY HH:MM" (e.g. "01. 15. 2026 07:37").
    static func parseHeader(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text

        // Match "MM. DD. YYYY" with flexible spacing/separators
        let pattern = #"(\d{1,2})\s*\.\s*(\d{1,2})\s*\.\s*(\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return result
        }

        let monthStr = String(text[Range(match.range(at: 1), in: text)!])
        let dayStr = String(text[Range(match.range(at: 2), in: text)!])
        let yearStr = String(text[Range(match.range(at: 3), in: text)!])

        guard let month = Int(monthStr), let day = Int(dayStr), let year = Int(yearStr) else {
            return result
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        // Try to extract time (HH:MM)
        let timePattern = #"(\d{1,2}):(\d{2})"#
        if let timeRegex = try? NSRegularExpression(pattern: timePattern),
           let timeMatch = timeRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(timeMatch.range(at: 1), in: text),
           let minuteRange = Range(timeMatch.range(at: 2), in: text) {
            components.hour = Int(text[hourRange])
            components.minute = Int(text[minuteRange])
        }

        result.scanDate = Calendar.current.date(from: components)
        return result
    }

    // MARK: - R2: Body Composition Analysis

    /// Extracts ICW, ECW, TBW (liters — no conversion), Dry Lean Mass, LBM, Body Fat Mass (mass → kg).
    static func parseBodyComposition(_ text: String, unit: DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text
        result.detectedUnit = unit

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()

            if lower.contains("intracellular") || (lower.contains("icw") && !lower.contains("ecw")) {
                // Water — store as-is (liters)
                result.intracellularWaterL = extractLastNumber(from: line)
            } else if lower.contains("extracellular") || (lower.hasPrefix("ecw") || lower.contains("ecw ")) {
                // Water — store as-is (liters)
                // Avoid matching "ECW/TBW" ratio lines
                if !lower.contains("ecw/tbw") {
                    result.extracellularWaterL = extractLastNumber(from: line)
                }
            } else if lower.contains("total body water") || lower.contains("tbw") {
                // Water — store as-is (liters)
                if !lower.contains("ecw/tbw") {
                    result.totalBodyWaterL = extractLastNumber(from: line)
                }
            } else if lower.contains("dry lean") {
                result.dryLeanMassKg = convertMass(extractLastNumber(from: line), unit: unit)
            } else if lower.contains("lean body mass") || lower.contains("lbm") {
                result.leanBodyMassKg = convertMass(extractLastNumber(from: line), unit: unit)
            } else if lower.contains("body fat mass") || lower.contains("bfm") {
                result.bodyFatMassKg = convertMass(extractLastNumber(from: line), unit: unit)
            }
        }

        return result
    }

    // MARK: - R3: Muscle-Fat Analysis

    /// Extracts Weight, SMM, Body Fat Mass (mass → kg).
    static func parseMuscleFat(_ text: String, unit: DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text
        result.detectedUnit = unit

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()

            if lower.contains("weight") {
                result.weightKg = convertMass(extractLastNumber(from: line), unit: unit)
            } else if lower.contains("skeletal muscle mass") || lower.contains("smm") {
                result.skeletalMuscleMassKg = convertMass(extractLastNumber(from: line), unit: unit)
            } else if lower.contains("body fat mass") || lower.contains("bfm") {
                result.bodyFatMassKg = convertMass(extractLastNumber(from: line), unit: unit)
            }
        }

        return result
    }

    // MARK: - R4: Obesity Analysis

    /// Extracts BMI and PBF (unitless, no conversion).
    static func parseObesity(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()

            if lower.contains("bmi") {
                result.bmi = extractLastNumber(from: line)
            } else if lower.contains("pbf") || lower.contains("percent body fat") || lower.contains("body fat") {
                result.bodyFatPct = extractLastNumber(from: line)
            }
        }

        return result
    }

    // MARK: - R5: Segmental Lean Analysis

    /// Extracts 5 segments, each with mass (→ kg) + sufficiency %.
    static func parseSegmentalLean(_ text: String, unit: DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text
        result.detectedUnit = unit

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()
            let numbers = extractAllNumbers(from: line)

            // Need at least mass value; sufficiency % is optional
            guard !numbers.isEmpty else { continue }

            let mass = convertMass(numbers.first, unit: unit)
            let pct = numbers.count >= 2 ? numbers.last : nil

            if lower.contains("right arm") {
                result.rightArmLeanKg = mass
                result.rightArmLeanPct = pct
            } else if lower.contains("left arm") {
                result.leftArmLeanKg = mass
                result.leftArmLeanPct = pct
            } else if lower.contains("trunk") {
                result.trunkLeanKg = mass
                result.trunkLeanPct = pct
            } else if lower.contains("right leg") {
                result.rightLegLeanKg = mass
                result.rightLegLeanPct = pct
            } else if lower.contains("left leg") {
                result.leftLegLeanKg = mass
                result.leftLegLeanPct = pct
            }
        }

        return result
    }

    // MARK: - R6: ECW/TBW Analysis

    /// Extracts ECW/TBW ratio (value < 1.0).
    static func parseEcwTbw(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text

        // Look for a decimal number less than 1.0 (the ratio)
        let numbers = extractAllNumbers(from: text)
        result.ecwTbwRatio = numbers.first(where: { $0 > 0 && $0 < 1.0 })

        return result
    }

    // MARK: - R7: Segmental Fat Analysis

    /// Extracts 5 segments, each with mass (→ kg) + sufficiency %.
    static func parseSegmentalFat(_ text: String, unit: DetectedUnit) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text
        result.detectedUnit = unit

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()
            let numbers = extractAllNumbers(from: line)

            guard !numbers.isEmpty else { continue }

            let mass = convertMass(numbers.first, unit: unit)
            let pct = numbers.count >= 2 ? numbers.last : nil

            if lower.contains("right arm") {
                result.rightArmFatKg = mass
                result.rightArmFatPct = pct
            } else if lower.contains("left arm") {
                result.leftArmFatKg = mass
                result.leftArmFatPct = pct
            } else if lower.contains("trunk") {
                result.trunkFatKg = mass
                result.trunkFatPct = pct
            } else if lower.contains("right leg") {
                result.rightLegFatKg = mass
                result.rightLegFatPct = pct
            } else if lower.contains("left leg") {
                result.leftLegFatKg = mass
                result.leftLegFatPct = pct
            }
        }

        return result
    }

    // MARK: - R8: Basal Metabolic Rate

    /// Extracts BMR kcal value.
    static func parseBMR(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text

        // BMR is typically a large number (1000-3000+)
        result.basalMetabolicRate = extractLastNumber(from: text)

        return result
    }

    // MARK: - R9: SMI

    /// Extracts Skeletal Muscle Index value.
    static func parseSMI(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text

        result.skeletalMuscleIndex = extractLastNumber(from: text)

        return result
    }

    // MARK: - R10: Visceral Fat

    /// Extracts visceral fat level.
    static func parseVisceralFat(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text

        result.visceralFatLevel = extractLastNumber(from: text)

        return result
    }

    // MARK: - Helpers

    /// Extracts the last number found in a string. Useful to skip range/label numbers
    /// and grab the actual measurement value which typically appears last.
    static func extractLastNumber(from text: String) -> Double? {
        extractAllNumbers(from: text).last
    }

    /// Extracts all numbers (including decimals) from a string.
    static func extractAllNumbers(from text: String) -> [Double] {
        let pattern = #"-?\d+\.?\d*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return Double(text[range])
        }
    }

    /// Converts a mass value from the detected unit to kg.
    /// Returns nil if the input is nil.
    private static func convertMass(_ value: Double?, unit: DetectedUnit) -> Double? {
        guard let value else { return nil }
        switch unit {
        case .lbs: return value * lbsToKg
        case .kg: return value
        }
    }
}
