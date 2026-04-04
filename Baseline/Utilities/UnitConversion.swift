import Foundation

enum UnitConversion {
    static let lbPerKg = 2.20462262

    static func lbToKg(_ lb: Double) -> Double {
        lb / lbPerKg
    }

    static func kgToLb(_ kg: Double) -> Double {
        kg * lbPerKg
    }

    static func formatWeight(_ value: Double, unit: String) -> String {
        String(format: "%.1f", value)
    }

    static func formatDelta(_ delta: Double) -> String {
        if delta > 0 {
            return "+\(String(format: "%.1f", delta))"
        } else if delta < 0 {
            return String(format: "%.1f", delta)
        } else {
            return "0.0"
        }
    }
}
