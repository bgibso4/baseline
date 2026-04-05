import Foundation
import SwiftData
import Observation

/// Time range filter for trend charts. Matches the approved Trends mockup
/// (M / 6M / Y / All). `.all` applies no date filter.
enum TimeRange: String, CaseIterable {
    case month = "M"       // 30 days
    case sixMonths = "6M"  // 180 days
    case year = "Y"        // 365 days
    case all = "All"       // no filter

    var days: Int? {
        switch self {
        case .month: return 30
        case .sixMonths: return 180
        case .year: return 365
        case .all: return nil
        }
    }
}

struct MovingAveragePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Trends screen VM — fetches weight entries within the selected time range
/// (forward-chronological), computes a 7-day moving average, and exposes
/// min/max for axis scaling.
@Observable
class TrendsViewModel {
    private let modelContext: ModelContext

    var timeRange: TimeRange = .month
    var entries: [WeightEntry] = []
    var movingAverage: [MovingAveragePoint] = []

    var minWeight: Double { entries.map(\.weight).min() ?? 0 }
    var maxWeight: Double { entries.map(\.weight).max() ?? 0 }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let sort = [SortDescriptor(\WeightEntry.date, order: .forward)]

        if let days = timeRange.days {
            let today = Calendar.current.startOfDay(for: Date())
            // Exclusive lower bound: "last N days" includes today and the
            // preceding N-1 days, yielding N entries for daily data.
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: today)!
            let descriptor = FetchDescriptor<WeightEntry>(
                predicate: #Predicate { $0.date > startDate },
                sortBy: sort
            )
            entries = (try? modelContext.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<WeightEntry>(sortBy: sort)
            entries = (try? modelContext.fetch(descriptor)) ?? []
        }

        calculateMovingAverage()
    }

    private func calculateMovingAverage() {
        let window = 7
        guard entries.count >= window else {
            movingAverage = []
            return
        }

        var result: [MovingAveragePoint] = []
        for i in (window - 1)..<entries.count {
            let windowSlice = entries[(i - window + 1)...i]
            let avg = windowSlice.map(\.weight).reduce(0, +) / Double(window)
            result.append(MovingAveragePoint(date: entries[i].date, value: avg))
        }
        movingAverage = result
    }
}
