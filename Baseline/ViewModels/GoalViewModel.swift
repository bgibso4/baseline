import Foundation
import SwiftData

@Observable
class GoalViewModel {

    private let modelContext: ModelContext
    var activeGoal: Goal?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<Goal>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        activeGoal = all.first { $0.status == .active }
    }

    func setGoal(metric: String, targetValue: Double, startValue: Double, targetDate: Date? = nil) {
        guard activeGoal == nil else { return }
        let goal = Goal(metric: metric, targetValue: targetValue, startValue: startValue, targetDate: targetDate)
        modelContext.insert(goal)
        try? modelContext.save()
        activeGoal = goal
    }

    func updateGoal(targetValue: Double, targetDate: Date?) {
        guard let goal = activeGoal else { return }
        goal.targetValue = targetValue
        goal.targetDate = targetDate.map { Calendar.current.startOfDay(for: $0) }
        try? modelContext.save()
    }

    func completeGoal() {
        guard let goal = activeGoal else { return }
        goal.status = .completed
        goal.completedDate = Date()
        try? modelContext.save()
        activeGoal = nil
    }

    func abandonGoal() {
        guard let goal = activeGoal else { return }
        goal.status = .abandoned
        goal.completedDate = Date()
        try? modelContext.save()
        activeGoal = nil
    }

    func checkCompletion(metricKey: String, currentValue: Double) -> Bool {
        guard let goal = activeGoal,
              goal.metric == metricKey,
              goal.isReached(currentValue: currentValue) else {
            return false
        }
        completeGoal()
        return true
    }
}
