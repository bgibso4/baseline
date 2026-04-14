import Foundation
import SwiftData

@Observable
class GoalViewModel {

    private let modelContext: ModelContext
    var activeGoals: [Goal] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    /// The active goal for a specific metric, or nil.
    func activeGoal(for metric: String) -> Goal? {
        activeGoals.first { $0.metric == metric }
    }

    /// Convenience: the active weight goal (used by Now screen).
    var activeWeightGoal: Goal? {
        activeGoal(for: TrendMetric.weight.rawValue)
    }

    func refresh() {
        let descriptor = FetchDescriptor<Goal>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        activeGoals = all.filter { $0.status == .active }
    }

    func setGoal(metric: String, targetValue: Double, startValue: Double, targetDate: Date? = nil) {
        // One active goal per metric
        guard activeGoal(for: metric) == nil else { return }
        let goal = Goal(metric: metric, targetValue: targetValue, startValue: startValue, targetDate: targetDate)
        modelContext.insert(goal)
        try? modelContext.save()
        activeGoals.append(goal)
    }

    func updateGoal(metric: String, targetValue: Double, targetDate: Date?) {
        guard let goal = activeGoal(for: metric) else { return }
        goal.targetValue = targetValue
        goal.targetDate = targetDate.map { Calendar.current.startOfDay(for: $0) }
        try? modelContext.save()
    }

    func completeGoal(metric: String) {
        guard let goal = activeGoal(for: metric) else { return }
        goal.status = .completed
        goal.completedDate = Date()
        try? modelContext.save()
        activeGoals.removeAll { $0.id == goal.id }
    }

    func abandonGoal(metric: String) {
        guard let goal = activeGoal(for: metric) else { return }
        goal.status = .abandoned
        goal.completedDate = Date()
        try? modelContext.save()
        activeGoals.removeAll { $0.id == goal.id }
    }

    /// Check if a goal for this metric is reached. Returns true (and marks completed) if so.
    func checkCompletion(metricKey: String, currentValue: Double) -> Bool {
        guard let goal = activeGoal(for: metricKey),
              goal.isReached(currentValue: currentValue) else {
            return false
        }
        completeGoal(metric: metricKey)
        return true
    }
}
