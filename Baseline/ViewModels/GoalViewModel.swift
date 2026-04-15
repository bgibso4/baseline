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
        do {
            let all = try modelContext.fetch(descriptor)
            activeGoals = all.filter { $0.status == .active }
        } catch {
            Log.goal.error("Fetch goals failed", error)
            activeGoals = []
        }
    }

    func setGoal(metric: String, targetValue: Double, startValue: Double, targetDate: Date? = nil) {
        // One active goal per metric
        guard activeGoal(for: metric) == nil else { return }
        let goal = Goal(metric: metric, targetValue: targetValue, startValue: startValue, targetDate: targetDate)
        modelContext.insert(goal)
        do {
            try modelContext.save()
            Log.goal.info("Set \(metric) goal: \(startValue) → \(targetValue)")
        } catch {
            Log.goal.error("Save goal failed", error)
        }
        activeGoals.append(goal)
    }

    func updateGoal(metric: String, targetValue: Double, targetDate: Date?) {
        guard let goal = activeGoal(for: metric) else { return }
        goal.targetValue = targetValue
        goal.targetDate = targetDate.map { Calendar.current.startOfDay(for: $0) }
        do {
            try modelContext.save()
            Log.goal.info("Updated \(metric) goal target to \(targetValue)")
        } catch {
            Log.goal.error("Update goal failed", error)
        }
    }

    func completeGoal(metric: String) {
        guard let goal = activeGoal(for: metric) else { return }
        goal.status = .completed
        goal.completedDate = Date()
        do {
            try modelContext.save()
            Log.goal.info("Completed \(metric) goal")
        } catch {
            Log.goal.error("Complete goal failed", error)
        }
        activeGoals.removeAll { $0.id == goal.id }
    }

    func abandonGoal(metric: String) {
        guard let goal = activeGoal(for: metric) else { return }
        goal.status = .abandoned
        goal.completedDate = Date()
        do {
            try modelContext.save()
            Log.goal.info("Abandoned \(metric) goal")
        } catch {
            Log.goal.error("Abandon goal failed", error)
        }
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
