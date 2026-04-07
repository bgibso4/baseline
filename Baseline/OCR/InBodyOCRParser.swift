import Foundation
import Vision
import UIKit

// MARK: - InBody OCR Parser

enum InBodyOCRParser {

    /// Conversion factor: 1 lb = 0.45359237 kg
    private static let lbsToKg: Double = 0.45359237

    // MARK: - Text Parsing

    static func parse(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Weight (lbs → kg)
            if lower.contains("weight") && !lower.contains("body fat") && !lower.contains("total body water") {
                if let lbs = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index) {
                    result.weightKg = lbs * lbsToKg
                }
            }

            // Body fat percentage (unitless)
            if lower.contains("percent body fat") || lower.contains("body fat %") || lower.contains("pbf") {
                result.bodyFatPct = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Skeletal muscle mass (lbs → kg)
            if lower.contains("skeletal muscle mass") || (lower.contains("smm") && !lower.contains("segmental")) {
                if let lbs = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index) {
                    result.skeletalMuscleMassKg = lbs * lbsToKg
                }
            }

            // Body fat mass (lbs → kg)
            if lower.contains("body fat mass") && !lower.contains("percent") {
                if let lbs = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index) {
                    result.bodyFatMassKg = lbs * lbsToKg
                }
            }

            // BMI (unitless)
            if lower.contains("bmi") && !lower.contains("score") {
                result.bmi = extractNumber(from: line)
            }

            // Total body water (liters — no conversion)
            if lower.contains("total body water") || (lower.contains("tbw") && !lower.contains("ecw") && !lower.contains("icw")) {
                result.totalBodyWaterL = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Intracellular water (liters)
            if lower.contains("intracellular water") || lower.hasPrefix("icw") {
                result.intracellularWaterL = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Extracellular water (liters)
            if lower.contains("extracellular water") || lower.hasPrefix("ecw") {
                result.extracellularWaterL = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Dry lean mass (lbs → kg)
            if lower.contains("dry lean mass") {
                if let lbs = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index) {
                    result.dryLeanMassKg = lbs * lbsToKg
                }
            }

            // Lean body mass (lbs → kg)
            if lower.contains("lean body mass") || (lower.contains("lbm") && !lower.contains("lean body mass")) {
                if let lbs = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index) {
                    result.leanBodyMassKg = lbs * lbsToKg
                }
            }

            // BMR (kcal — no conversion)
            if lower.contains("basal metabolic rate") || lower.contains("bmr") {
                result.basalMetabolicRate = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // InBody Score (unitless)
            if lower.contains("inbody score") {
                result.inBodyScore = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Segmental lean (lbs → kg)
            if lower.contains("segmental lean") {
                parseSegmentalLean(lines: Array(lines.dropFirst(index + 1)), result: &result)
            }

            // Segmental fat (lbs → kg)
            if lower.contains("segmental fat") {
                parseSegmentalFat(lines: Array(lines.dropFirst(index + 1)), result: &result)
            }
        }

        return result
    }

    // MARK: - Image OCR (Vision framework)

    static func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Helpers

    private static func extractNumber(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    private static func extractNumber(fromNextLine lines: [String], after index: Int) -> Double? {
        guard index + 1 < lines.count else { return nil }
        return extractNumber(from: lines[index + 1])
    }

    private static func parseSegmentalLean(lines: [String], result: inout InBodyParseResult) {
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            if lower.contains("right arm") { result.rightArmLeanKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("left arm") { result.leftArmLeanKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("trunk") { result.trunkLeanKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("right leg") { result.rightLegLeanKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("left leg") { result.leftLegLeanKg = (extractNumber(from: line) ?? 0) * lbsToKg }
        }
    }

    private static func parseSegmentalFat(lines: [String], result: inout InBodyParseResult) {
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            if lower.contains("right arm") { result.rightArmFatKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("left arm") { result.leftArmFatKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("trunk") { result.trunkFatKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("right leg") { result.rightLegFatKg = (extractNumber(from: line) ?? 0) * lbsToKg }
            else if lower.contains("left leg") { result.leftLegFatKg = (extractNumber(from: line) ?? 0) * lbsToKg }
        }
    }
}
