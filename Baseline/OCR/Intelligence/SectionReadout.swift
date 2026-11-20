import Foundation

/// What was read from one section of the sheet, before any checking.
struct SectionReadout: Equatable {
    /// Field key → value as read.
    var values: [String: Double] = [:]
    /// A second printed copy of a field that another section also reports
    /// (weight and body fat mass appear in both the table and the bar chart).
    var repeated: [String: Double] = [:]
    /// The test date from the header, as printed.
    var testDate: DateComponents?
}
