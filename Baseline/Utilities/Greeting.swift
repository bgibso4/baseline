import Foundation

/// Pure time-of-day greeting logic for the Now screen header.
/// No SwiftUI/UIKit imports — unit-testable without a simulator.
enum Greeting {
    /// "Good morning" 05:00–11:59, "Good afternoon" 12:00–16:59,
    /// "Good evening" otherwise (17:00 through 04:59, wrapping midnight).
    static func salutation(at date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// Display-ready greeting for the Now header.
    struct Display: Equatable {
        /// First line — the salutation, with a trailing comma only when a
        /// name line follows (never a dangling "Good morning,").
        let salutationLine: String
        /// Second line — the trimmed name, or nil when unset.
        let nameLine: String?
        /// Combined VoiceOver label ("Good morning, Ben" / "Good morning").
        let accessibilityLabel: String
    }

    /// Compose the header lines for a raw (possibly empty/padded) name.
    static func display(
        name: String,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Display {
        let salutation = salutation(at: date, calendar: calendar)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return Display(
                salutationLine: salutation,
                nameLine: nil,
                accessibilityLabel: salutation
            )
        }
        return Display(
            salutationLine: "\(salutation),",
            nameLine: trimmed,
            accessibilityLabel: "\(salutation), \(trimmed)"
        )
    }
}
