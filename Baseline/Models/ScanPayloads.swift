import Foundation

/// Strongly-typed union of decoded scan payloads
enum ScanContent {
    case inBody(InBodyPayload)
}

/// Full InBody 570 result set
struct InBodyPayload: Codable, Equatable {
    // Core
    var weightKg: Double
    var skeletalMuscleMassKg: Double
    var bodyFatMassKg: Double
    var bodyFatPct: Double
    var totalBodyWaterL: Double
    var bmi: Double
    var basalMetabolicRate: Double

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
}
