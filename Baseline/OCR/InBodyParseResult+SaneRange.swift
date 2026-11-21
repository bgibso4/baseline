import Foundation

extension InBodyParseResult {

    /// The plausible range for a field, by key. `nil` for fields with no
    /// defined range (`inBodyScore`) and for unknown keys.
    static func saneRange(forKey key: String) -> ClosedRange<Double>? {
        if let range = namedRanges[key] { return range }
        if key.hasSuffix("LeanPct") { return SaneRange.segLeanPct }
        if key.hasSuffix("FatKg") { return SaneRange.segFatLbs }
        if key.hasSuffix("FatPct") { return SaneRange.segFatPct }
        return nil
    }

    private static let namedRanges: [String: ClosedRange<Double>] = [
        "weightKg": SaneRange.weightLbs,
        "skeletalMuscleMassKg": SaneRange.smmLbs,
        "bodyFatMassKg": SaneRange.bfmLbs,
        "bodyFatPct": SaneRange.bfpPct,
        "totalBodyWaterL": SaneRange.tbwLbs,
        "bmi": SaneRange.bmi,
        "basalMetabolicRate": SaneRange.bmrKcal,
        "intracellularWaterL": SaneRange.icwLbs,
        "extracellularWaterL": SaneRange.ecwLbs,
        "dryLeanMassKg": SaneRange.dlmLbs,
        "leanBodyMassKg": SaneRange.lbmLbs,
        "ecwTbwRatio": SaneRange.ecwTbw,
        "skeletalMuscleIndex": SaneRange.smi,
        "visceralFatLevel": SaneRange.visceralFat,
        "rightArmLeanKg": SaneRange.segLeanArmLbs,
        "leftArmLeanKg": SaneRange.segLeanArmLbs,
        "trunkLeanKg": SaneRange.segLeanTrunkLbs,
        "rightLegLeanKg": SaneRange.segLeanLegLbs,
        "leftLegLeanKg": SaneRange.segLeanLegLbs
    ]
}
