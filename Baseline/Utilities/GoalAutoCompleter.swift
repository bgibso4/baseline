import Foundation
import SwiftData

/// Auto-marks active goals as completed when a just-saved metric value
/// reaches the target. Called from `BodyViewModel.saveMeasurement` and
/// `ScanEntryViewModel.save()` so body-fat/waist/lean-mass goals complete
/// themselves the same way weight goals do via NowView.
///
/// Values are keyed by `TrendMetric.rawValue` in the user's preferred
/// display unit (matches how goal target/start values were entered and
/// stored in `SetGoalSheet`).
enum GoalAutoCompleter {

    @discardableResult
    static func checkCompletions(values: [String: Double], in modelContext: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<Goal>()
        let active = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.status == .active }

        var completed: [String] = []
        for goal in active {
            guard let current = values[goal.metric],
                  goal.isReached(currentValue: current) else { continue }
            goal.status = .completed
            goal.completedDate = Date()
            completed.append(goal.metric)
        }
        guard !completed.isEmpty else { return [] }
        do {
            try modelContext.save()
            Log.goal.info("Auto-completed goals: \(completed.joined(separator: ", "))")
        } catch {
            Log.goal.error("Auto-complete save failed", error)
        }
        return completed
    }
}
