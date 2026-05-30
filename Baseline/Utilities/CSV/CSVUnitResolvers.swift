import Foundation

// MARK: - Unit resolution

/// Resolves the canonical unit for a weight row from, in priority order:
/// 1. An explicit unit column cell value
/// 2. A parenthesized hint in the weight column's header (`Weight (kg)`)
/// 3. The supplied default (usually the user's app-wide preference)
///
/// Returns nil if no source yields a recognisable unit — callers decide
/// whether to fall back further or reject the row.
enum WeightUnitResolver {
    static func resolve(
        explicit: String?,
        headerHint: String?,
        default defaultUnit: String
    ) -> String? {
        if let normalized = normalize(explicit) { return normalized }
        if let normalized = normalize(headerHint) { return normalized }
        if let normalized = normalize(defaultUnit) { return normalized }
        return nil
    }

    private static func normalize(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        switch raw.lowercased() {
        case "lb", "lbs", "pound", "pounds": return "lb"
        case "kg", "kgs", "kilogram", "kilograms": return "kg"
        default: return nil
        }
    }
}

/// Resolves the canonical length unit for a measurement row and converts
/// raw numeric values to centimetres (Baseline's storage unit). Falls
/// back to the supplied default if neither the column nor the header
/// identifies a unit.
enum LengthUnitResolver {
    static func resolveUnit(
        explicit: String?,
        headerHint: String?,
        default defaultUnit: String
    ) -> String? {
        if let n = normalize(explicit) { return n }
        if let n = normalize(headerHint) { return n }
        return normalize(defaultUnit)
    }

    static func toCentimeters(_ value: Double, unit: String) -> Double {
        switch unit {
        case "cm": return value
        case "in": return value * 2.54
        default: return value
        }
    }

    private static func normalize(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        switch raw.lowercased() {
        case "cm", "centimeter", "centimeters", "centimetres": return "cm"
        case "in", "inch", "inches": return "in"
        default: return nil
        }
    }
}
