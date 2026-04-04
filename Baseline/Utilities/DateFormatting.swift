import Foundation

enum DateFormatting {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let fullFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func shortDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func fullDate(_ date: Date) -> String {
        fullFormatter.string(from: date)
    }

    static func iso8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static func fromISO8601(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func isYesterday(_ date: Date) -> Bool {
        Calendar.current.isDateInYesterday(date)
    }
}
