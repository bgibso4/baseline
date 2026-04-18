import Foundation
import SwiftData
import Observation

@Observable
class NowViewModel {
    private let modelContext: ModelContext

    var todayEntry: WeightEntry?
    var previousEntry: WeightEntry?
    var recentWeights: [WeightEntry] = []

    var delta: Double? {
        guard let today = todayEntry, let previous = previousEntry else { return nil }
        let todayDisplay = UnitConversion.displayWeight(today.weight, storedUnit: today.unit)
        let prevDisplay = UnitConversion.displayWeight(previous.weight, storedUnit: previous.unit)
        return todayDisplay - prevDisplay
    }

    /// Latest weight converted to the user's preferred display unit.
    var lastWeight: Double? {
        if let todayEntry {
            return UnitConversion.displayWeight(todayEntry.weight, storedUnit: todayEntry.unit)
        }
        guard let previousEntry else { return nil }
        return UnitConversion.displayWeight(previousEntry.weight, storedUnit: previousEntry.unit)
    }

    /// Preferred weight unit ("lb" / "kg"). Owns the UserDefaults read so views
    /// don't reach into storage directly. A proper UserPreferences service
    /// arrives with Settings in Task 18.
    var unit: String {
        UnitConversion.preferredWeightUnit
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!

        // Fetch today's entry (any time today)
        var todayDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= todayStart && $0.date < tomorrowStart }
        )
        todayDescriptor.fetchLimit = 1
        do {
            todayEntry = try modelContext.fetch(todayDescriptor).first
        } catch {
            Log.data.error("Fetch today's weight failed", error)
        }

        // Fetch most recent entry before today
        var previousDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date < todayStart },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        previousDescriptor.fetchLimit = 1
        do {
            previousEntry = try modelContext.fetch(previousDescriptor).first
        } catch {
            Log.data.error("Fetch previous weight failed", error)
        }

        // Fetch all weight entries for stats (filtered by range in the view)
        let recentDescriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        do {
            recentWeights = try modelContext.fetch(recentDescriptor)
        } catch {
            Log.data.error("Fetch recent weights failed", error)
            recentWeights = []
        }
    }
}
