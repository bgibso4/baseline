import Foundation

// MARK: - Date parsing

/// Tries a fixed list of format strings in order until one matches. When
/// a separate time column is also provided, each base format is tried
/// alongside `HH:mm:ss` and `HH:mm` variants.
///
/// **Extension point:** to accept a new date format, add its
/// `DateFormatter.dateFormat` string to `baseFormats`. Preformatted
/// `DateFormatter` instances are cached at load time (POSIX locale,
/// `twoDigitStartDate` anchored to year 2000) so parsing 10,000+ rows
/// doesn't allocate a formatter per row.
enum FlexibleDateParser {
    /// Format strings for the date portion. Ordered so that 2-digit-year
    /// variants are tried BEFORE 4-digit — otherwise DateFormatter in
    /// lenient mode will parse "5/26/21" as the year 0021. We also set
    /// `isLenient = false` below to make format boundaries strict.
    private static let baseFormats: [String] = [
        // ISO 8601 variants
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",

        // Slash-separated — 2-digit year first to anchor into the 2000s
        // before the 4-digit patterns have a chance to match loosely.
        "MM/dd/yy",
        "M/d/yy",
        "MM/dd/yyyy",
        "M/d/yyyy",

        // Other
        "yyyy/MM/dd",
        "dd-MM-yyyy"
    ]

    /// Pre-built formatters covering each base format plus two common
    /// time-column append variants. Order matches `baseFormats`.
    private static let formatters: [DateFormatter] = {
        // `Calendar.date(from:)` requires enough components to pin down a
        // unique instant — year alone returns nil. Supply month + day so
        // twoDigitStartDate is actually set and `yy` patterns anchor to
        // the 2000s instead of falling back to DateFormatter's default
        // sliding window (which can wander into year 0001 CE).
        let anchorYear2000: Date? = {
            var cal = Calendar(identifier: .gregorian)
            cal.locale = Locale(identifier: "en_US_POSIX")
            return cal.date(from: DateComponents(year: 2000, month: 1, day: 1))
        }()

        return baseFormats.flatMap { base -> [DateFormatter] in
            [base, "\(base) HH:mm:ss", "\(base) HH:mm"].map { pattern in
                let f = DateFormatter()
                f.calendar = Calendar(identifier: .gregorian)
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                f.dateFormat = pattern
                f.twoDigitStartDate = anchorYear2000
                f.isLenient = false
                return f
            }
        }
    }()

    /// Parses a date string (optionally combined with a separate time
    /// column) against every registered format, returning the first
    /// successful match whose year is plausibly modern. Returns nil if
    /// nothing parses, or if every match lands outside 1900..3000 (which
    /// indicates a `yyyy` pattern accepted a 2-digit year literally).
    static func parse(date dateString: String, time timeString: String? = nil) -> Date? {
        let dateTrim = dateString.trimmingCharacters(in: .whitespaces)
        guard !dateTrim.isEmpty else { return nil }

        let combined: String
        if let timeString, !timeString.trimmingCharacters(in: .whitespaces).isEmpty {
            combined = "\(dateTrim) \(timeString.trimmingCharacters(in: .whitespaces))"
        } else {
            combined = dateTrim
        }

        // Calendar for year validation — same gregorian/POSIX as parsers.
        var validationCal = Calendar(identifier: .gregorian)
        validationCal.locale = Locale(identifier: "en_US_POSIX")
        validationCal.timeZone = TimeZone.current

        for formatter in formatters {
            guard let candidate = formatter.date(from: combined) else { continue }
            let year = validationCal.component(.year, from: candidate)
            if year >= 1900 && year <= 3000 {
                return candidate
            }
            // Otherwise this formatter produced an obviously-wrong year
            // (e.g. `yyyy` pattern gobbled a 2-digit year as year 21).
            // Skip it and let the next format attempt a real match.
        }
        return nil
    }
}
