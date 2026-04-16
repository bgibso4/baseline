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

    // MARK: - Consensus Voting

    /// All field keys that can be extracted from a scan.
    static let allFieldKeys: [String] = [
        "weightKg", "skeletalMuscleMassKg", "bodyFatMassKg", "bodyFatPct",
        "totalBodyWaterL", "bmi", "basalMetabolicRate",
        "intracellularWaterL", "extracellularWaterL", "dryLeanMassKg", "leanBodyMassKg",
        "inBodyScore", "ecwTbwRatio", "skeletalMuscleIndex", "visceralFatLevel",
        "rightArmLeanKg", "leftArmLeanKg", "trunkLeanKg", "rightLegLeanKg", "leftLegLeanKg",
        "rightArmFatKg", "leftArmFatKg", "trunkFatKg", "rightLegFatKg", "leftLegFatKg",
        "rightArmLeanPct", "leftArmLeanPct", "trunkLeanPct", "rightLegLeanPct", "leftLegLeanPct",
        "rightArmFatPct", "leftArmFatPct", "trunkFatPct", "rightLegFatPct", "leftLegFatPct",
    ]

    /// Get a field value by key.
    func value(forKey key: String) -> Double? {
        switch key {
        case "weightKg": return weightKg
        case "skeletalMuscleMassKg": return skeletalMuscleMassKg
        case "bodyFatMassKg": return bodyFatMassKg
        case "bodyFatPct": return bodyFatPct
        case "totalBodyWaterL": return totalBodyWaterL
        case "bmi": return bmi
        case "basalMetabolicRate": return basalMetabolicRate
        case "intracellularWaterL": return intracellularWaterL
        case "extracellularWaterL": return extracellularWaterL
        case "dryLeanMassKg": return dryLeanMassKg
        case "leanBodyMassKg": return leanBodyMassKg
        case "inBodyScore": return inBodyScore
        case "rightArmLeanKg": return rightArmLeanKg
        case "leftArmLeanKg": return leftArmLeanKg
        case "trunkLeanKg": return trunkLeanKg
        case "rightLegLeanKg": return rightLegLeanKg
        case "leftLegLeanKg": return leftLegLeanKg
        case "rightArmFatKg": return rightArmFatKg
        case "leftArmFatKg": return leftArmFatKg
        case "trunkFatKg": return trunkFatKg
        case "rightLegFatKg": return rightLegFatKg
        case "leftLegFatKg": return leftLegFatKg
        case "ecwTbwRatio": return ecwTbwRatio
        case "skeletalMuscleIndex": return skeletalMuscleIndex
        case "visceralFatLevel": return visceralFatLevel
        case "rightArmLeanPct": return rightArmLeanPct
        case "leftArmLeanPct": return leftArmLeanPct
        case "trunkLeanPct": return trunkLeanPct
        case "rightLegLeanPct": return rightLegLeanPct
        case "leftLegLeanPct": return leftLegLeanPct
        case "rightArmFatPct": return rightArmFatPct
        case "leftArmFatPct": return leftArmFatPct
        case "trunkFatPct": return trunkFatPct
        case "rightLegFatPct": return rightLegFatPct
        case "leftLegFatPct": return leftLegFatPct
        default: return nil
        }
    }

    /// Set a field value by key.
    mutating func setValue(_ value: Double?, forKey key: String) {
        switch key {
        case "weightKg": weightKg = value
        case "skeletalMuscleMassKg": skeletalMuscleMassKg = value
        case "bodyFatMassKg": bodyFatMassKg = value
        case "bodyFatPct": bodyFatPct = value
        case "totalBodyWaterL": totalBodyWaterL = value
        case "bmi": bmi = value
        case "basalMetabolicRate": basalMetabolicRate = value
        case "intracellularWaterL": intracellularWaterL = value
        case "extracellularWaterL": extracellularWaterL = value
        case "dryLeanMassKg": dryLeanMassKg = value
        case "leanBodyMassKg": leanBodyMassKg = value
        case "inBodyScore": inBodyScore = value
        case "rightArmLeanKg": rightArmLeanKg = value
        case "leftArmLeanKg": leftArmLeanKg = value
        case "trunkLeanKg": trunkLeanKg = value
        case "rightLegLeanKg": rightLegLeanKg = value
        case "leftLegLeanKg": leftLegLeanKg = value
        case "rightArmFatKg": rightArmFatKg = value
        case "leftArmFatKg": leftArmFatKg = value
        case "trunkFatKg": trunkFatKg = value
        case "rightLegFatKg": rightLegFatKg = value
        case "leftLegFatKg": leftLegFatKg = value
        case "ecwTbwRatio": ecwTbwRatio = value
        case "skeletalMuscleIndex": skeletalMuscleIndex = value
        case "visceralFatLevel": visceralFatLevel = value
        case "rightArmLeanPct": rightArmLeanPct = value
        case "leftArmLeanPct": leftArmLeanPct = value
        case "trunkLeanPct": trunkLeanPct = value
        case "rightLegLeanPct": rightLegLeanPct = value
        case "leftLegLeanPct": leftLegLeanPct = value
        case "rightArmFatPct": rightArmFatPct = value
        case "leftArmFatPct": leftArmFatPct = value
        case "trunkFatPct": trunkFatPct = value
        case "rightLegFatPct": rightLegFatPct = value
        case "leftLegFatPct": leftLegFatPct = value
        default: break
        }
    }

    /// Produce a consensus result from multiple scan results using majority voting.
    ///
    /// For each field:
    /// - Values within 1% of each other are considered "agreeing"
    /// - If majority agree → use that value, confidence 0.95
    /// - If 2 of 3 agree → use majority value, confidence 0.85
    /// - If all differ → use the one with highest Apple OCR confidence, confidence 0.3
    /// - If only 1 scan has the value → use it, keep its original confidence
    /// - Apple's OCR confidence is used as tiebreaker, not primary signal
    static func consensusVote(_ results: [InBodyParseResult], userEditedFields: Set<String> = []) -> InBodyParseResult {
        guard !results.isEmpty else { return InBodyParseResult() }

        // Single scan — no consensus possible. Cap all confidence low to flag for review.
        if results.count == 1 {
            var single = results[0]
            for key in allFieldKeys where single.value(forKey: key) != nil {
                single.confidence[key] = min(single.confidence[key] ?? 0, 0.4)
            }
            return single
        }

        var final = InBodyParseResult()
        final.scanDate = results.compactMap(\.scanDate).min()
        final.rawText = results.map(\.rawText).filter { !$0.isEmpty }.joined(separator: "\n---\n")
        final.detectedUnit = results.first?.detectedUnit ?? .lbs

        for key in allFieldKeys {
            guard !userEditedFields.contains(key) else { continue }

            // Collect all non-nil values with their confidence
            let candidates: [(value: Double, conf: Float)] = results.compactMap { r in
                guard let v = r.value(forKey: key) else { return nil }
                return (v, r.confidence[key] ?? 0)
            }

            guard !candidates.isEmpty else { continue }

            if candidates.count == 1 {
                // Only one scan had this field — keep it but cap confidence
                // (no corroboration from other scans)
                final.setValue(candidates[0].value, forKey: key)
                final.confidence[key] = min(candidates[0].conf, 0.6)
                continue
            }

            // Group values that agree (within 1% tolerance)
            let groups = groupByAgreement(candidates.map(\.value), tolerance: 0.01)
            let largest = groups.max(by: { $0.count < $1.count })!

            if largest.count == candidates.count {
                // All agree — very high confidence
                let avg = largest.reduce(0, +) / Double(largest.count)
                final.setValue(avg, forKey: key)
                final.confidence[key] = 0.95
            } else if largest.count > 1 {
                // Majority agrees — high confidence, use majority average
                let avg = largest.reduce(0, +) / Double(largest.count)
                final.setValue(avg, forKey: key)
                final.confidence[key] = 0.85
            } else {
                // All differ — low confidence, pick highest Apple OCR confidence
                let best = candidates.max(by: { $0.conf < $1.conf })!
                final.setValue(best.value, forKey: key)
                final.confidence[key] = 0.3
            }
        }

        return final
    }

    /// Group values that are within `tolerance` (relative) of each other.
    private static func groupByAgreement(_ values: [Double], tolerance: Double) -> [[Double]] {
        var groups: [[Double]] = []
        for value in values {
            var placed = false
            for i in groups.indices {
                let representative = groups[i][0]
                let diff = abs(value - representative) / max(abs(representative), 0.01)
                if diff <= tolerance {
                    groups[i].append(value)
                    placed = true
                    break
                }
            }
            if !placed {
                groups.append([value])
            }
        }
        return groups
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
