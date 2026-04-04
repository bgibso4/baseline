import Foundation

enum MeasurementType: String, CaseIterable, Codable {
    // Manual tape measurements
    case waist = "waist"
    case neck = "neck"
    case chest = "chest"
    case rightArm = "right_arm"
    case leftArm = "left_arm"
    case rightThigh = "right_thigh"
    case leftThigh = "left_thigh"
    case hips = "hips"

    // Body comp metrics (from InBody or manual)
    case bodyFatPercentage = "body_fat_pct"
    case skeletalMuscleMass = "skeletal_muscle_mass"
    case bodyFatMass = "body_fat_mass"
    case leanBodyMass = "lean_body_mass"
    case totalBodyWater = "total_body_water"
    case bmi = "bmi"
    case basalMetabolicRate = "basal_metabolic_rate"
    case inBodyScore = "inbody_score"

    // Segmental lean
    case rightArmLean = "right_arm_lean"
    case leftArmLean = "left_arm_lean"
    case trunkLean = "trunk_lean"
    case rightLegLean = "right_leg_lean"
    case leftLegLean = "left_leg_lean"

    // Segmental fat
    case rightArmFat = "right_arm_fat"
    case leftArmFat = "left_arm_fat"
    case trunkFat = "trunk_fat"
    case rightLegFat = "right_leg_fat"
    case leftLegFat = "left_leg_fat"

    // Custom
    case custom = "custom"

    var displayName: String {
        switch self {
        case .waist: return "Waist"
        case .neck: return "Neck"
        case .chest: return "Chest"
        case .rightArm: return "Right Arm"
        case .leftArm: return "Left Arm"
        case .rightThigh: return "Right Thigh"
        case .leftThigh: return "Left Thigh"
        case .hips: return "Hips"
        case .bodyFatPercentage: return "Body Fat %"
        case .skeletalMuscleMass: return "Skeletal Muscle Mass"
        case .bodyFatMass: return "Body Fat Mass"
        case .leanBodyMass: return "Lean Body Mass"
        case .totalBodyWater: return "Total Body Water"
        case .bmi: return "BMI"
        case .basalMetabolicRate: return "Basal Metabolic Rate"
        case .inBodyScore: return "InBody Score"
        case .rightArmLean: return "Right Arm (Lean)"
        case .leftArmLean: return "Left Arm (Lean)"
        case .trunkLean: return "Trunk (Lean)"
        case .rightLegLean: return "Right Leg (Lean)"
        case .leftLegLean: return "Left Leg (Lean)"
        case .rightArmFat: return "Right Arm (Fat)"
        case .leftArmFat: return "Left Arm (Fat)"
        case .trunkFat: return "Trunk (Fat)"
        case .rightLegFat: return "Right Leg (Fat)"
        case .leftLegFat: return "Left Leg (Fat)"
        case .custom: return "Custom"
        }
    }

    var defaultUnit: String {
        switch self {
        case .bodyFatPercentage: return "%"
        case .bmi, .inBodyScore, .basalMetabolicRate: return ""
        case .totalBodyWater: return "L"
        case .skeletalMuscleMass, .bodyFatMass, .leanBodyMass,
             .rightArmLean, .leftArmLean, .trunkLean, .rightLegLean, .leftLegLean,
             .rightArmFat, .leftArmFat, .trunkFat, .rightLegFat, .leftLegFat:
            return "lb"
        case .custom: return ""
        default:
            return "in"
        }
    }
}

enum MeasurementSource: String, Codable {
    case manual = "manual"
    case inbody = "inbody"
}
