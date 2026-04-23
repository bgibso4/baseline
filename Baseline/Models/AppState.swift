import Foundation
import Observation

/// Lightweight shared state for cross-tab communication.
///
/// Injected as an environment object in `BaselineApp`. Used by BodyView to
/// request a Trends-tab switch with a pre-selected metric, and by TrendsView
/// to read that metric.
@Observable
class AppState {
    var selectedTab: AppTab = .now
    var trendMetric: String = "Weight"

    /// When true, TrendsView will open the SetGoalSheet on its next
    /// appear. Used by the goal-reached celebration on NowView so
    /// tapping "Set New Goal" actually lands the user on the goal
    /// creation surface instead of silently dismissing.
    var showSetGoalOnTrendsAppear: Bool = false
}
