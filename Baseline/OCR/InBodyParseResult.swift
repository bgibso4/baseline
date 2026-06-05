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

    // MARK: - Field Registry
    //
    // Single source of truth for OCR-extractable Double fields. `value(forKey:)`,
    // `setValue(_:forKey:)`, `merge(with:)`, and `consensusVote(_:)` all derive
    // from this list — add a field here and every dispatch picks it up automatically.
    //
    // Order is preserved for stable iteration in tests and debug logs.
    static let allFields: [(key: String, keyPath: WritableKeyPath<InBodyParseResult, Double?>)] = [
        ("weightKg", \.weightKg),
        ("skeletalMuscleMassKg", \.skeletalMuscleMassKg),
        ("bodyFatMassKg", \.bodyFatMassKg),
        ("bodyFatPct", \.bodyFatPct),
        ("totalBodyWaterL", \.totalBodyWaterL),
        ("bmi", \.bmi),
        ("basalMetabolicRate", \.basalMetabolicRate),
        ("intracellularWaterL", \.intracellularWaterL),
        ("extracellularWaterL", \.extracellularWaterL),
        ("dryLeanMassKg", \.dryLeanMassKg),
        ("leanBodyMassKg", \.leanBodyMassKg),
        ("inBodyScore", \.inBodyScore),
        ("ecwTbwRatio", \.ecwTbwRatio),
        ("skeletalMuscleIndex", \.skeletalMuscleIndex),
        ("visceralFatLevel", \.visceralFatLevel),
        ("rightArmLeanKg", \.rightArmLeanKg),
        ("leftArmLeanKg", \.leftArmLeanKg),
        ("trunkLeanKg", \.trunkLeanKg),
        ("rightLegLeanKg", \.rightLegLeanKg),
        ("leftLegLeanKg", \.leftLegLeanKg),
        ("rightArmFatKg", \.rightArmFatKg),
        ("leftArmFatKg", \.leftArmFatKg),
        ("trunkFatKg", \.trunkFatKg),
        ("rightLegFatKg", \.rightLegFatKg),
        ("leftLegFatKg", \.leftLegFatKg),
        ("rightArmLeanPct", \.rightArmLeanPct),
        ("leftArmLeanPct", \.leftArmLeanPct),
        ("trunkLeanPct", \.trunkLeanPct),
        ("rightLegLeanPct", \.rightLegLeanPct),
        ("leftLegLeanPct", \.leftLegLeanPct),
        ("rightArmFatPct", \.rightArmFatPct),
        ("leftArmFatPct", \.leftArmFatPct),
        ("trunkFatPct", \.trunkFatPct),
        ("rightLegFatPct", \.rightLegFatPct),
        ("leftLegFatPct", \.leftLegFatPct)
    ]

    /// All field keys in stable order. Derived from `allFields` so the two can't drift.
    static let allFieldKeys: [String] = allFields.map(\.key)

    /// Indexed lookup for O(1) key → keypath resolution.
    private static let keyPathByKey: [String: WritableKeyPath<InBodyParseResult, Double?>] =
        Dictionary(uniqueKeysWithValues: allFields.map { ($0.key, $0.keyPath) })

    /// Get a field value by key. Returns nil for unset fields or unknown keys.
    func value(forKey key: String) -> Double? {
        Self.keyPathByKey[key].flatMap { self[keyPath: $0] }
    }

    /// Set a field value by key. No-ops for unknown keys.
    mutating func setValue(_ value: Double?, forKey key: String) {
        guard let keyPath = Self.keyPathByKey[key] else { return }
        self[keyPath: keyPath] = value
    }

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
        for (key, keyPath) in Self.allFields {
            guard !userEditedFields.contains(key) else { continue }
            mergeField(key: key, keyPath: keyPath, from: other)
        }

        // Merge raw text for debugging
        if !other.rawText.isEmpty {
            rawText = rawText.isEmpty ? other.rawText : rawText + "\n---\n" + other.rawText
        }

        // Keep earliest scan date found
        if let otherDate = other.scanDate {
            scanDate = scanDate.map { min($0, otherDate) } ?? otherDate
        }
    }

    /// Per-field merge: fill blanks, otherwise let higher confidence win.
    /// Pre-existing behavior preserved: confidence is only written when a higher-
    /// confidence overwrite happens — the nil→value case carries no confidence update.
    private mutating func mergeField(
        key: String,
        keyPath: WritableKeyPath<InBodyParseResult, Double?>,
        from other: InBodyParseResult
    ) {
        switch (self[keyPath: keyPath], other[keyPath: keyPath]) {
        case (.none, .some(let new)):
            self[keyPath: keyPath] = new
        case (.some, .some(let new)):
            let currentConf = confidence[key] ?? 0
            let newConf = other.confidence[key] ?? 0
            if newConf > currentConf {
                self[keyPath: keyPath] = new
                confidence[key] = newConf
            }
        case (.some, .none), (.none, .none):
            break
        }
    }
}
