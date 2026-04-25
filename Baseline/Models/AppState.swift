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

    /// One-shot request from another tab (e.g. BodyView) to switch the
    /// Trends tab to a specific metric. TrendsView consumes this on appear
    /// (or via onChange when already visible) and resets it to nil so
    /// returning to Trends later preserves the user's last in-tab selection.
    var trendMetric: String? = nil

    /// When true, TrendsView will open the SetGoalSheet on its next
    /// appear. Used by the goal-reached celebration on NowView so
    /// tapping "Set New Goal" actually lands the user on the goal
    /// creation surface instead of silently dismissing.
    var showSetGoalOnTrendsAppear: Bool = false

    // MARK: - Preloaded view models
    //
    // Created eagerly by MainTabView at app launch so the first-time tab
    // switch doesn't trigger a synchronous "create VM + refresh" reflow
    // mid-cross-fade. Without preloading, TrendsView.onAppear fires during
    // the tab transition, the VM comes in, the layout reflows, and the
    // user sees the goal card + chart text jumping positions during the
    // fade. Preloading makes first render look identical to subsequent
    // renders.
    var preloadedTrendsVM: AnyObject?
    var preloadedGoalVM: AnyObject?
    var preloadedBodyVM: AnyObject?
}
