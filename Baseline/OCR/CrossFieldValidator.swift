import Foundation

/// Math-consistency check for InBody 570 parsed values.
///
/// The parser can produce wrong-but-confident values when it picks up a
/// tick-mark number, an impedance reading, or a neighbouring field by
/// mistake. Most extraction errors show up as broken physical identities:
/// weight should equal lean mass + fat mass, body water should equal
/// intracellular + extracellular, etc.
///
/// `validate(_:)` checks those identities against the parser's output
/// and returns the set of field keys that look inconsistent. Callers can
/// merge this into their low-confidence set alongside the confidence-
/// threshold and sane-range checks that already exist.
enum CrossFieldValidator {

    /// Validates a dictionary of field-key → string-value (as stored on
    /// `ScanEntryViewModel.fields`). Fields that are missing or non-numeric
    /// are ignored — each check only runs when all of its inputs are present.
    ///
    /// When a check fails, *all* fields participating in the check are
    /// flagged. We can't tell which one is wrong without more information,
    /// so we err on the side of surfacing the inconsistency to the user.
    static func validate(_ fields: [String: String]) -> Set<String> {
        var failing: Set<String> = []
        let v: (String) -> Double? = { Double(fields[$0, default: ""]) }

        let weight = v("weightKg")
        let bfm = v("bodyFatMassKg")
        let lbm = v("leanBodyMassKg")
        let tbw = v("totalBodyWaterL")
        let dlm = v("dryLeanMassKg")
        let icw = v("intracellularWaterL")
        let ecw = v("extracellularWaterL")
        let pbf = v("bodyFatPct")
        let ecwTbwRatio = v("ecwTbwRatio")

        // weight == bodyFatMass + leanBodyMass  (2% tolerance, floor 0.5)
        if let w = weight, let b = bfm, let l = lbm {
            let expected = b + l
            let tolerance = max(0.5, w * 0.02)
            if abs(w - expected) > tolerance {
                failing.insert("weightKg")
                failing.insert("bodyFatMassKg")
                failing.insert("leanBodyMassKg")
            }
        }

        // leanBodyMass == dryLeanMass + totalBodyWater  (2% tolerance)
        if let l = lbm, let d = dlm, let t = tbw {
            let expected = d + t
            let tolerance = max(0.5, l * 0.02)
            if abs(l - expected) > tolerance {
                failing.insert("leanBodyMassKg")
                failing.insert("dryLeanMassKg")
                failing.insert("totalBodyWaterL")
            }
        }

        // totalBodyWater == intracellularWater + extracellularWater (2% tolerance)
        if let t = tbw, let i = icw, let e = ecw {
            let expected = i + e
            let tolerance = max(0.5, t * 0.02)
            if abs(t - expected) > tolerance {
                failing.insert("totalBodyWaterL")
                failing.insert("intracellularWaterL")
                failing.insert("extracellularWaterL")
            }
        }

        // bodyFatPct == bodyFatMass / weight * 100  (±1 percentage point)
        // This is the check that catches most bar-chart-region reads going
        // to the wrong tick mark.
        if let w = weight, let b = bfm, let p = pbf, w > 0 {
            let expected = b / w * 100
            if abs(expected - p) > 1.0 {
                failing.insert("bodyFatPct")
            }
        }

        // ecwTbwRatio == ecw / tbw  (±0.005)
        if let e = ecw, let t = tbw, let r = ecwTbwRatio, t > 0 {
            let expected = e / t
            if abs(expected - r) > 0.005 {
                failing.insert("ecwTbwRatio")
            }
        }

        return failing
    }
}
