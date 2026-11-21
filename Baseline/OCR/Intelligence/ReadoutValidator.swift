import Foundation

/// Turns raw section readouts into an `InBodyParseResult` whose confidence
/// can be trusted.
///
/// The on-device model reports no confidence of its own and tends to make
/// up a value rather than leave one blank, so trust comes from checks made
/// here: plausibility ranges and agreement between values printed twice.
enum ReadoutValidator {

    /// Above `ScanEntryViewModel`'s review threshold.
    static let trusted: Float = 0.9
    /// Below the review threshold: the field is shown flagged.
    static let flagged: Float = 0.3

    /// Two reads of the same printed number agree within this.
    private static let agreementTolerance = 0.05
    private static let oldestAcceptedYears = 5

    static func assemble(_ readouts: [SheetSection: SectionReadout], now: Date) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.isSelfValidated = true

        for readout in readouts.values {
            for (key, value) in readout.values where isPlausible(value, forKey: key) {
                result.setValue(value, forKey: key)
                result.confidence[key] = trusted
            }
        }
        for readout in readouts.values {
            for (key, copy) in readout.repeated where isPlausible(copy, forKey: key) {
                if let value = result.value(forKey: key) {
                    if abs(value - copy) > agreementTolerance { result.confidence[key] = flagged }
                } else {
                    result.setValue(copy, forKey: key)
                    result.confidence[key] = flagged
                }
            }
        }
        result.scanDate = readouts.values.lazy.compactMap(\.testDate).compactMap { acceptedDate($0, now: now) }.first
        return result
    }

    /// No real InBody value is zero or negative, and the model answers 0 for
    /// values it cannot read — so zero is rejected even where a range allows it.
    private static func isPlausible(_ value: Double, forKey key: String) -> Bool {
        guard value > 0, let range = InBodyParseResult.saneRange(forKey: key) else { return false }
        return range.contains(value)
    }

    private static func acceptedDate(_ components: DateComponents, now: Date) -> Date? {
        let calendar = Calendar.current
        guard components.isValidDate(in: calendar),
              let date = calendar.date(from: components),
              let oldest = calendar.date(byAdding: .year, value: -oldestAcceptedYears, to: now),
              date <= now, date >= oldest else { return nil }
        return date
    }
}
