import Foundation
import SwiftData

enum GoalStatus: String, Codable {
    case active
    case completed
    case abandoned
}

@Model
final class Goal {
    var id: UUID = UUID()
    var metric: String = ""
    @Attribute(.allowsCloudEncryption) var targetValue: Double = 0.0
    var targetDate: Date?
    @Attribute(.allowsCloudEncryption) var startValue: Double = 0.0
    var startDate: Date = Date()
    var status: GoalStatus = GoalStatus.active
    var completedDate: Date?
    var createdAt: Date = Date()

    init(
        metric: String,
        targetValue: Double,
        startValue: Double,
        targetDate: Date? = nil
    ) {
        self.id = UUID()
        self.metric = metric
        self.targetValue = targetValue
        self.startValue = startValue
        self.startDate = Date()
        self.targetDate = targetDate.map { Calendar.current.startOfDay(for: $0) }
        self.status = .active
        self.createdAt = Date()
    }

    var isDecreasing: Bool {
        targetValue < startValue
    }

    func progress(currentValue: Double) -> Double {
        let totalDistance = abs(targetValue - startValue)
        guard totalDistance > 0 else { return 1.0 }
        let moved = isDecreasing
            ? startValue - currentValue
            : currentValue - startValue
        return min(max(moved / totalDistance, 0.0), 1.0)
    }

    func remaining(currentValue: Double) -> Double {
        let diff = abs(currentValue - targetValue)
        return isReached(currentValue: currentValue) ? 0.0 : diff
    }

    func isReached(currentValue: Double) -> Bool {
        let tolerance = 0.01
        if isDecreasing {
            return currentValue <= targetValue + tolerance
        } else {
            return currentValue >= targetValue - tolerance
        }
    }

    var daysRemaining: Int? {
        guard let targetDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: targetDate).day
        return max(days ?? 0, 0)
    }
}
