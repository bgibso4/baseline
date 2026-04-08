import Foundation
import Vision
import UIKit

/// Region-based OCR pipeline for InBody 570 result sheets.
///
/// Pipeline: image → perspective correct → crop regions → OCR each → parse → merge → confidence score
enum InBodyOCRParser {

    /// Full pipeline: process a captured image and return parsed results with confidence.
    static func processImage(_ image: UIImage) async -> InBodyParseResult {
        // 1. Perspective correction
        let corrected = await DocumentCorrector.correctPerspective(image)

        // 2. Crop all regions
        let regionImages = InBody570RegionMap.cropAll(from: corrected)

        // 3. Detect unit from the muscle-fat region (R3 contains "Weight lbs/kg")
        var detectedUnit: DetectedUnit = .lbs
        if let muscleFatImage = regionImages.first(where: { $0.0.id == "R3" }) {
            let r3Text = await recognizeText(from: muscleFatImage.1)
            detectedUnit = InBody570RegionParsers.detectUnit(from: r3Text)
        }

        // 4. OCR + parse each region sequentially (memory pressure concern)
        var merged = InBodyParseResult()
        merged.detectedUnit = detectedUnit

        for (region, regionImage) in regionImages {
            let text = await recognizeTextWithConfidence(from: regionImage)
            let regionResult = parseRegion(region, text: text.text, confidence: text.avgConfidence, unit: detectedUnit)
            merged.merge(with: regionResult, userEditedFields: [])
        }

        return merged
    }

    // MARK: - Per-Region Dispatch

    private static func parseRegion(
        _ region: InBody570RegionMap.Region,
        text: String,
        confidence: Float,
        unit: DetectedUnit
    ) -> InBodyParseResult {
        var result: InBodyParseResult

        switch region.id {
        case "R1": result = InBody570RegionParsers.parseHeader(text)
        case "R2": result = InBody570RegionParsers.parseBodyComposition(text, unit: unit)
        case "R3": result = InBody570RegionParsers.parseMuscleFat(text, unit: unit)
        case "R4": result = InBody570RegionParsers.parseObesity(text)
        case "R5": result = InBody570RegionParsers.parseSegmentalLean(text, unit: unit)
        case "R6": result = InBody570RegionParsers.parseEcwTbw(text)
        case "R7": result = InBody570RegionParsers.parseSegmentalFat(text, unit: unit)
        case "R8": result = InBody570RegionParsers.parseBMR(text)
        case "R9": result = InBody570RegionParsers.parseSMI(text)
        case "R10": result = InBody570RegionParsers.parseVisceralFat(text)
        default: result = InBodyParseResult()
        }

        // Apply region-level confidence to all extracted fields
        applyConfidence(to: &result, confidence: confidence)
        return result
    }

    /// Set confidence for all non-nil Double fields in the result.
    private static func applyConfidence(to result: inout InBodyParseResult, confidence: Float) {
        // List all Double? field key paths and their string keys
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
            ("rightArmLeanKg", result.rightArmLeanKg),
            ("leftArmLeanKg", result.leftArmLeanKg),
            ("trunkLeanKg", result.trunkLeanKg),
            ("rightLegLeanKg", result.rightLegLeanKg),
            ("leftLegLeanKg", result.leftLegLeanKg),
            ("rightArmLeanPct", result.rightArmLeanPct),
            ("leftArmLeanPct", result.leftArmLeanPct),
            ("trunkLeanPct", result.trunkLeanPct),
            ("rightLegLeanPct", result.rightLegLeanPct),
            ("leftLegLeanPct", result.leftLegLeanPct),
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
}
