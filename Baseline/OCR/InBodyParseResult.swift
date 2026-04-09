import Foundation

// MARK: - Detected Unit

enum DetectedUnit {
    case lbs
    case kg
}

// MARK: - Parse Result (all fields optional — OCR may miss any)

struct InBodyParseResult {
    // Core (required for InBodyPayload)
    var weightKg: Double?
    var skeletalMuscleMassKg: Double?
    var bodyFatMassKg: Double?
    var bodyFatPct: Double?
    var totalBodyWaterL: Double?
    var bmi: Double?
    var basalMetabolicRate: Double?

    // Body Composition Analysis
    var intracellularWaterL: Double?
    var extracellularWaterL: Double?
    var dryLeanMassKg: Double?
    var leanBodyMassKg: Double?
    var inBodyScore: Double?

    // Segmental Lean (5 segments)
    var rightArmLeanKg: Double?
    var leftArmLeanKg: Double?
    var trunkLeanKg: Double?
    var rightLegLeanKg: Double?
    var leftLegLeanKg: Double?

    // Segmental Fat (5 segments)
    var rightArmFatKg: Double?
    var leftArmFatKg: Double?
    var trunkFatKg: Double?
    var rightLegFatKg: Double?
    var leftLegFatKg: Double?

    // ECW/TBW
    var ecwTbwRatio: Double?

    // SMI & Visceral Fat
    var skeletalMuscleIndex: Double?
    var visceralFatLevel: Double?

    // Segmental sufficiency percentages (lean)
    var rightArmLeanPct: Double?
    var leftArmLeanPct: Double?
    var trunkLeanPct: Double?
    var rightLegLeanPct: Double?
    var leftLegLeanPct: Double?

    // Segmental sufficiency percentages (fat)
    var rightArmFatPct: Double?
    var leftArmFatPct: Double?
    var trunkFatPct: Double?
    var rightLegFatPct: Double?
    var leftLegFatPct: Double?

    // OCR metadata
    var scanDate: Date?
    var rawText: String = ""
    var confidence: [String: Float] = [:]
    var detectedUnit: DetectedUnit = .lbs

    // MARK: - Conversion to InBodyPayload

    enum ConversionError: Error, LocalizedError {
        case missingRequiredFields([String])

        var errorDescription: String? {
            switch self {
            case .missingRequiredFields(let fields):
                return "Missing required fields: \(fields.joined(separator: ", "))"
            }
        }
    }

    func toPayload() throws -> InBodyPayload {
        var missing: [String] = []
        if weightKg == nil { missing.append("weightKg") }
        if skeletalMuscleMassKg == nil { missing.append("skeletalMuscleMassKg") }
        if bodyFatMassKg == nil { missing.append("bodyFatMassKg") }
        if bodyFatPct == nil { missing.append("bodyFatPct") }
        if totalBodyWaterL == nil { missing.append("totalBodyWaterL") }
        if bmi == nil { missing.append("bmi") }
        if basalMetabolicRate == nil { missing.append("basalMetabolicRate") }

        guard missing.isEmpty else {
            throw ConversionError.missingRequiredFields(missing)
        }

        return InBodyPayload(
            weightKg: weightKg!,
            skeletalMuscleMassKg: skeletalMuscleMassKg!,
            bodyFatMassKg: bodyFatMassKg!,
            bodyFatPct: bodyFatPct!,
            totalBodyWaterL: totalBodyWaterL!,
            bmi: bmi!,
            basalMetabolicRate: basalMetabolicRate!,
            intracellularWaterL: intracellularWaterL,
            extracellularWaterL: extracellularWaterL,
            dryLeanMassKg: dryLeanMassKg,
            leanBodyMassKg: leanBodyMassKg,
            inBodyScore: inBodyScore,
            rightArmLeanKg: rightArmLeanKg,
            leftArmLeanKg: leftArmLeanKg,
            trunkLeanKg: trunkLeanKg,
            rightLegLeanKg: rightLegLeanKg,
            leftLegLeanKg: leftLegLeanKg,
            rightArmFatKg: rightArmFatKg,
            leftArmFatKg: leftArmFatKg,
            trunkFatKg: trunkFatKg,
            rightLegFatKg: rightLegFatKg,
            leftLegFatKg: leftLegFatKg,
            ecwTbwRatio: ecwTbwRatio,
            skeletalMuscleIndex: skeletalMuscleIndex,
            visceralFatLevel: visceralFatLevel,
            rightArmLeanPct: rightArmLeanPct,
            leftArmLeanPct: leftArmLeanPct,
            trunkLeanPct: trunkLeanPct,
            rightLegLeanPct: rightLegLeanPct,
            leftLegLeanPct: leftLegLeanPct,
            rightArmFatPct: rightArmFatPct,
            leftArmFatPct: leftArmFatPct,
            trunkFatPct: trunkFatPct,
            rightLegFatPct: rightLegFatPct,
            leftLegFatPct: leftLegFatPct
        )
    }

    // MARK: - Merge

    /// Merges another parse result into this one. Higher confidence wins per field.
    /// Fields in `userEditedFields` are never overwritten.
    mutating func merge(with other: InBodyParseResult, userEditedFields: Set<String> = []) {
        func pick<T>(_ key: String, current: T?, new: T?) -> T? {
            guard !userEditedFields.contains(key) else { return current }
            switch (current, new) {
            case (nil, let n): return n
            case (let c, nil): return c
            case (let c, let n):
                let currentConf = confidence[key] ?? 0
                let newConf = other.confidence[key] ?? 0
                if newConf > currentConf {
                    confidence[key] = newConf
                    return n
                }
                return c
            }
        }

        weightKg = pick("weightKg", current: weightKg, new: other.weightKg)
        skeletalMuscleMassKg = pick("skeletalMuscleMassKg", current: skeletalMuscleMassKg, new: other.skeletalMuscleMassKg)
        bodyFatMassKg = pick("bodyFatMassKg", current: bodyFatMassKg, new: other.bodyFatMassKg)
        bodyFatPct = pick("bodyFatPct", current: bodyFatPct, new: other.bodyFatPct)
        totalBodyWaterL = pick("totalBodyWaterL", current: totalBodyWaterL, new: other.totalBodyWaterL)
        bmi = pick("bmi", current: bmi, new: other.bmi)
        basalMetabolicRate = pick("basalMetabolicRate", current: basalMetabolicRate, new: other.basalMetabolicRate)
        intracellularWaterL = pick("intracellularWaterL", current: intracellularWaterL, new: other.intracellularWaterL)
        extracellularWaterL = pick("extracellularWaterL", current: extracellularWaterL, new: other.extracellularWaterL)
        dryLeanMassKg = pick("dryLeanMassKg", current: dryLeanMassKg, new: other.dryLeanMassKg)
        leanBodyMassKg = pick("leanBodyMassKg", current: leanBodyMassKg, new: other.leanBodyMassKg)
        inBodyScore = pick("inBodyScore", current: inBodyScore, new: other.inBodyScore)
        rightArmLeanKg = pick("rightArmLeanKg", current: rightArmLeanKg, new: other.rightArmLeanKg)
        leftArmLeanKg = pick("leftArmLeanKg", current: leftArmLeanKg, new: other.leftArmLeanKg)
        trunkLeanKg = pick("trunkLeanKg", current: trunkLeanKg, new: other.trunkLeanKg)
        rightLegLeanKg = pick("rightLegLeanKg", current: rightLegLeanKg, new: other.rightLegLeanKg)
        leftLegLeanKg = pick("leftLegLeanKg", current: leftLegLeanKg, new: other.leftLegLeanKg)
        rightArmFatKg = pick("rightArmFatKg", current: rightArmFatKg, new: other.rightArmFatKg)
        leftArmFatKg = pick("leftArmFatKg", current: leftArmFatKg, new: other.leftArmFatKg)
        trunkFatKg = pick("trunkFatKg", current: trunkFatKg, new: other.trunkFatKg)
        rightLegFatKg = pick("rightLegFatKg", current: rightLegFatKg, new: other.rightLegFatKg)
        leftLegFatKg = pick("leftLegFatKg", current: leftLegFatKg, new: other.leftLegFatKg)
        ecwTbwRatio = pick("ecwTbwRatio", current: ecwTbwRatio, new: other.ecwTbwRatio)
        skeletalMuscleIndex = pick("skeletalMuscleIndex", current: skeletalMuscleIndex, new: other.skeletalMuscleIndex)
        visceralFatLevel = pick("visceralFatLevel", current: visceralFatLevel, new: other.visceralFatLevel)
        rightArmLeanPct = pick("rightArmLeanPct", current: rightArmLeanPct, new: other.rightArmLeanPct)
        leftArmLeanPct = pick("leftArmLeanPct", current: leftArmLeanPct, new: other.leftArmLeanPct)
        trunkLeanPct = pick("trunkLeanPct", current: trunkLeanPct, new: other.trunkLeanPct)
        rightLegLeanPct = pick("rightLegLeanPct", current: rightLegLeanPct, new: other.rightLegLeanPct)
        leftLegLeanPct = pick("leftLegLeanPct", current: leftLegLeanPct, new: other.leftLegLeanPct)
        rightArmFatPct = pick("rightArmFatPct", current: rightArmFatPct, new: other.rightArmFatPct)
        leftArmFatPct = pick("leftArmFatPct", current: leftArmFatPct, new: other.leftArmFatPct)
        trunkFatPct = pick("trunkFatPct", current: trunkFatPct, new: other.trunkFatPct)
        rightLegFatPct = pick("rightLegFatPct", current: rightLegFatPct, new: other.rightLegFatPct)
        leftLegFatPct = pick("leftLegFatPct", current: leftLegFatPct, new: other.leftLegFatPct)

        // Merge raw text for debugging
        if !other.rawText.isEmpty {
            rawText = rawText.isEmpty ? other.rawText : rawText + "\n---\n" + other.rawText
        }

        // Keep earliest scan date found
        if let otherDate = other.scanDate {
            scanDate = scanDate.map { min($0, otherDate) } ?? otherDate
        }
    }
}
