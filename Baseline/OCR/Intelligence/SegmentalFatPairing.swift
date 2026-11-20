import Foundation

/// Turns the two columns read from the Segmental Fat list into fields.
///
/// Each row reads "Right Arm ( 0.2lbs) 14.4%". The model reads a column of
/// five numbers reliably but mixes rows when asked for lbs and % together,
/// so each column is read on its own and paired here.
enum SegmentalFatPairing {

    private static let parts = ["rightArm", "leftArm", "trunk", "rightLeg", "leftLeg"]

    /// A column contributes its five fields only when it has exactly five
    /// plausible values; a short, long or implausible column is dropped whole.
    static func fields(lbs: [Double], percents: [Double]) -> [String: Double] {
        column(lbs.map(oneDecimalPlace), suffix: "FatKg")
            .merging(column(percents, suffix: "FatPct")) { first, _ in first }
    }

    private static func column(_ values: [Double], suffix: String) -> [String: Double] {
        guard values.count == parts.count else { return [:] }
        let keys = parts.map { $0 + suffix }
        for (key, value) in zip(keys, values) {
            guard let range = InBodyParseResult.saneRange(forKey: key), range.contains(value) else { return [:] }
        }
        return Dictionary(uniqueKeysWithValues: zip(keys, values))
    }

    /// The sheet prints these with one decimal place, directly followed by
    /// "lbs" — whose "l" is often read as a trailing 1 ("0.2lbs" → 0.21).
    private static func oneDecimalPlace(_ value: Double) -> Double {
        (value * 10).rounded(.down) / 10
    }
}
