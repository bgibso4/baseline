import Foundation

enum MeasurementType: String, CaseIterable, Codable {
    case waist, hips, chest, neck
    case armLeft, armRight
    case thighLeft, thighRight
    case calfLeft, calfRight

    var displayName: String {
        switch self {
        case .waist: return "Waist"
        case .hips: return "Hips"
        case .chest: return "Chest"
        case .neck: return "Neck"
        case .armLeft: return "Left Arm"
        case .armRight: return "Right Arm"
        case .thighLeft: return "Left Thigh"
        case .thighRight: return "Right Thigh"
        case .calfLeft: return "Left Calf"
        case .calfRight: return "Right Calf"
        }
    }

    var defaultUnitLabel: String { "cm" }
}
