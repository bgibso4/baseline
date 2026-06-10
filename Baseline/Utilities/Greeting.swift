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
}
