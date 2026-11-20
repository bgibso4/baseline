import Foundation

/// Turns the ordered list of numbers read from the Segmental Lean chart
/// into fields.
///
/// The chart prints two results per body part (lbs, then %) for right arm,
/// left arm, trunk, right leg, left leg. Asking the model for "the lbs and
/// % of each body part" makes it swap and mix rows; asking only for the
/// numbers in reading order, and pairing them here, does not.
enum SegmentalLeanPairing {

    /// Field keys in the order the numbers are printed, top to bottom.
    static let keysInPrintOrder: [String] = [
        "rightArmLeanKg", "rightArmLeanPct", "leftArmLeanKg", "leftArmLeanPct",
        "trunkLeanKg", "trunkLeanPct", "rightLegLeanKg", "rightLegLeanPct",
        "leftLegLeanKg", "leftLegLeanPct"
    ]

    /// All ten fields, or nothing. A missing, extra or misplaced number
    /// shifts every later one into the wrong slot, so a list that is the
    /// wrong length or has any value outside its field's plausible range is
    /// rejected whole rather than trusted in part.
    ///
    /// The one partial list accepted is five numbers that are all masses or
    /// all percentages: the model sometimes lists one figure per body part.
    /// An arm's lbs and % ranges do not overlap, so the two cannot be confused.
    static func fields(from numbers: [Double]) -> [String: Double] {
        if numbers.count == keysInPrintOrder.count / 2 { return singleColumn(numbers) }
        guard numbers.count == keysInPrintOrder.count,
              let ordered = lbsFirst(numbers) else { return [:] }
        for (key, value) in zip(keysInPrintOrder, ordered) {
            guard let range = InBodyParseResult.saneRange(forKey: key), range.contains(value) else { return [:] }
        }
        return Dictionary(uniqueKeysWithValues: zip(keysInPrintOrder, ordered))
    }

    private static func singleColumn(_ numbers: [Double]) -> [String: Double] {
        for suffix in ["Kg", "Pct"] {
            let keys = keysInPrintOrder.filter { $0.hasSuffix(suffix) }
            let fits = zip(keys, numbers).allSatisfy { key, value in
                InBodyParseResult.saneRange(forKey: key)?.contains(value) == true
            }
            if fits { return Dictionary(uniqueKeysWithValues: zip(keys, numbers)) }
        }
        return [:]
    }

    /// Positions of the arm and leg pairs; the trunk is pair 2.
    private static let limbPairs = [0, 1, 3, 4]

    /// Puts every pair in (lbs, %) order.
    ///
    /// Depending on how the two figures are offset on a given printout, the
    /// model lists each pair lbs-first or %-first — but consistently down the
    /// chart. For an arm or leg the lbs figure is always the smaller of the
    /// two, so the limbs reveal which way round the list is. The trunk then
    /// follows them, because a trunk's lbs can exceed its %. Returns `nil`
    /// when the limbs disagree: the list is not a clean column of pairs.
    private static func lbsFirst(_ numbers: [Double]) -> [Double]? {
        let limbsLbsFirst = limbPairs.map { numbers[2 * $0] < numbers[2 * $0 + 1] }
        guard let listIsLbsFirst = limbsLbsFirst.first,
              limbsLbsFirst.allSatisfy({ $0 == listIsLbsFirst }) else { return nil }
        guard !listIsLbsFirst else { return numbers }
        return stride(from: 0, to: numbers.count, by: 2).flatMap { [numbers[$0 + 1], numbers[$0]] }
    }
}
