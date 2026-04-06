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
        return today.weight - previous.weight
    }

    var lastWeight: Double? {
        if let todayEntry { return todayEntry.weight }
        return previousEntry?.weight
    }

    /// Preferred weight unit ("lb" / "kg"). Owns the UserDefaults read so views
    /// don't reach into storage directly. A proper UserPreferences service
    /// arrives with Settings in Task 18.
    var unit: String {
        todayEntry?.unit
            ?? UserDefaults.standard.string(forKey: "weightUnit")
            ?? "lb"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let today = Calendar.current.startOfDay(for: Date())

        // Fetch today's entry
        var todayDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == today }
        )
        todayDescriptor.fetchLimit = 1
        todayEntry = try? modelContext.fetch(todayDescriptor).first

        // Fetch most recent entry before today
        var previousDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date < today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        previousDescriptor.fetchLimit = 1
        previousEntry = try? modelContext.fetch(previousDescriptor).first

        // Fetch all weight entries for stats (filtered by range in the view)
        let recentDescriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        recentWeights = (try? modelContext.fetch(recentDescriptor)) ?? []
    }
}
