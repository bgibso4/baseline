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

    /// SF Symbol name for Body tab tiles.
    var sfSymbol: String {
        switch self {
        case .waist: return "ruler"
        case .hips: return "figure.stand"
        case .chest: return "heart"
        case .neck: return "circle.dotted"
        case .armLeft, .armRight: return "figure.arms.open"
        case .thighLeft, .thighRight: return "figure.walk"
        case .calfLeft, .calfRight: return "figure.run"
        }
    }

    /// Tile label for Body tab (shorter than displayName for bilateral).
    var tileLabel: String {
        switch self {
        case .armLeft: return "Arm \u{00B7} L"
        case .armRight: return "Arm \u{00B7} R"
        case .thighLeft: return "Thigh \u{00B7} L"
        case .thighRight: return "Thigh \u{00B7} R"
        case .calfLeft: return "Calf \u{00B7} L"
        case .calfRight: return "Calf \u{00B7} R"
        default: return displayName
        }
    }
}
