import UIKit

/// Lightweight haptic feedback helpers.
///
/// Wraps UIKit feedback generators behind simple static calls.
/// All methods are safe to call from any thread — UIKit dispatches
/// the actual taptic engine work internally.
enum Haptics {
    /// Light tap — stepper increments, minor interactions.
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium tap — confirmations, mode switches.
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Success notification — save actions, completed flows.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Selection tick — toggles, segmented controls, pickers.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
