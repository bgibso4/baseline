import Foundation

enum UnitConversion {
    static let lbPerKg = 2.20462262
    static let cmPerInch = 2.54

    static func lbToKg(_ lb: Double) -> Double {
        lb / lbPerKg
    }

    static func kgToLb(_ kg: Double) -> Double {
        kg * lbPerKg
    }

    static func cmToIn(_ cm: Double) -> Double {
        cm / cmPerInch
    }

    static func inToCm(_ inches: Double) -> Double {
        inches * cmPerInch
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

    // MARK: - Display Helpers (read user preference)

    /// Returns the display value and unit string for a mass value stored in kg.
    static func displayMass(_ kg: Double) -> (value: Double, unit: String) {
        let pref = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        return pref == "kg" ? (kg, "kg") : (kgToLb(kg), "lb")
    }

    /// Returns the display value and unit string for a length value stored in cm.
    static func displayLength(_ cm: Double) -> (value: Double, unit: String) {
        let pref = UserDefaults.standard.string(forKey: "lengthUnit") ?? "in"
        return pref == "in" ? (cmToIn(cm), "in") : (cm, "cm")
    }

    /// Formatted mass string with 1 decimal place.
    static func formattedMass(_ kg: Double) -> (text: String, unit: String) {
        let (value, unit) = displayMass(kg)
        return (String(format: "%.1f", value), unit)
    }

    /// Formatted length string with 1 decimal place.
    static func formattedLength(_ cm: Double) -> (text: String, unit: String) {
        let (value, unit) = displayLength(cm)
        return (String(format: "%.1f", value), unit)
    }
}
