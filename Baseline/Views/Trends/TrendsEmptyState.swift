import SwiftUI

/// Cold-start empty state for the Trends screen — shown when the selected
/// metric has no data at all (distinct from the "stepped back into an empty
/// window" placeholder, which lives with the chart section).
///
/// Tailors the CTA to the selected metric — weight routes to the Now tab
/// (fastest path), measurements route to Body (where the log sheet lives),
/// and body-comp metrics prompt for a scan. Reports the destination via
/// `onSelectTab`.
struct TrendsEmptyState: View {
    let metric: TrendMetric
    let onSelectTab: (AppTab) -> Void

    var body: some View {
        let (message, ctaLabel, ctaAction): (String, String, () -> Void) = {
            switch metric.group {
            case .core where metric == .weight:
                return (
                    "Log a weigh-in to start building your trend.",
                    "Log Weigh-In",
                    { onSelectTab(.now) }
                )
            case .measurements:
                return (
                    "Log a measurement on the Body tab to start tracking it here.",
                    "Go to Body",
                    { onSelectTab(.body) }
                )
            default:
                return (
                    "Add an InBody scan on the Body tab to start tracking this metric.",
                    "Go to Body",
                    { onSelectTab(.body) }
                )
            }
        }()

        return EmptyStateCard(
            systemImage: metric.icon,
            title: "No data yet",
            message: message,
            ctaLabel: ctaLabel,
            ctaAction: ctaAction
        )
        .padding(.top, 60)
    }
}
