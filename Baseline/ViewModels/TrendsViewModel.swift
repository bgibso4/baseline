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

/// Selectable metric for the Trends chart.
enum TrendMetric: String, CaseIterable {
    case weight = "Weight"
    case bodyFatPct = "Body Fat %"
    case skeletalMuscle = "Skeletal Muscle"
    case bmi = "BMI"
    case fatMass = "Fat Mass"
    case waist = "Waist"

    var unit: String {
        switch self {
        case .weight: return "lb"
        case .bodyFatPct: return "%"
        case .skeletalMuscle, .fatMass: return "lb"
        case .bmi: return ""
        case .waist: return "in"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass"
        case .bodyFatPct: return "drop.fill"
        case .skeletalMuscle: return "figure.strengthtraining.traditional"
        case .bmi: return "chart.bar"
        case .fatMass: return "scalemass"
        case .waist: return "ruler"
        }
    }
}

struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct MovingAveragePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Trends screen VM — fetches data for the selected metric within the selected
/// time range, computes a 7-day moving average, and exposes generic data points
/// for charting.
@Observable
class TrendsViewModel {
    private let modelContext: ModelContext

    var timeRange: TimeRange = .month
    var selectedMetric: TrendMetric = .weight

    /// Generic data points for the currently selected metric.
    var dataPoints: [TrendDataPoint] = []
    var movingAverage: [MovingAveragePoint] = []

    /// Legacy accessor — weight entries (only populated when metric == .weight).
    var entries: [WeightEntry] = []

    var minValue: Double { dataPoints.map(\.value).min() ?? 0 }
    var maxValue: Double { dataPoints.map(\.value).max() ?? 0 }

    /// Legacy aliases for weight-only tests.
    var minWeight: Double { minValue }
    var maxWeight: Double { maxValue }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        switch selectedMetric {
        case .weight:
            refreshWeight()
        case .bodyFatPct:
            refreshScanMetric { $0.bodyFatPct }
        case .skeletalMuscle:
            refreshScanMetric { UnitConversion.kgToLb($0.skeletalMuscleMassKg) }
        case .bmi:
            refreshScanMetric { $0.bmi }
        case .fatMass:
            refreshScanMetric { UnitConversion.kgToLb($0.bodyFatMassKg) }
        case .waist:
            refreshWaist()
        }

        calculateMovingAverage()
    }

    // MARK: - Weight

    private func refreshWeight() {
        let sort = [SortDescriptor(\WeightEntry.date, order: .forward)]

        if let days = timeRange.days {
            let today = Calendar.current.startOfDay(for: Date())
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

        dataPoints = entries.map { TrendDataPoint(date: $0.date, value: $0.weight) }
    }

    // MARK: - Scan-derived metrics

    private func refreshScanMetric(extract: (InBodyPayload) -> Double) {
        entries = []
        let sort = [SortDescriptor(\Scan.date, order: .forward)]

        let scans: [Scan]
        if let days = timeRange.days {
            let today = Calendar.current.startOfDay(for: Date())
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: today)!
            let descriptor = FetchDescriptor<Scan>(
                predicate: #Predicate { $0.date > startDate },
                sortBy: sort
            )
            scans = (try? modelContext.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<Scan>(sortBy: sort)
            scans = (try? modelContext.fetch(descriptor)) ?? []
        }

        dataPoints = scans.compactMap { scan in
            guard let content = try? scan.decoded(),
                  case .inBody(let payload) = content else { return nil }
            return TrendDataPoint(date: scan.date, value: extract(payload))
        }
    }

    // MARK: - Waist (tape measurement)

    private func refreshWaist() {
        entries = []
        let sort = [SortDescriptor(\Measurement.date, order: .forward)]
        let waistRaw = MeasurementType.waist.rawValue

        let measurements: [Measurement]
        if let days = timeRange.days {
            let today = Calendar.current.startOfDay(for: Date())
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: today)!
            let descriptor = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.type == waistRaw && $0.date > startDate },
                sortBy: sort
            )
            measurements = (try? modelContext.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.type == waistRaw },
                sortBy: sort
            )
            measurements = (try? modelContext.fetch(descriptor)) ?? []
        }

        dataPoints = measurements.map { m in
            TrendDataPoint(date: m.date, value: m.valueCm / 2.54)
        }
    }

    // MARK: - Moving Average

    private func calculateMovingAverage() {
        let window = 7
        guard dataPoints.count >= window else {
            movingAverage = []
            return
        }

        var result: [MovingAveragePoint] = []
        for i in (window - 1)..<dataPoints.count {
            let windowSlice = dataPoints[(i - window + 1)...i]
            let avg = windowSlice.map(\.value).reduce(0, +) / Double(window)
            result.append(MovingAveragePoint(date: dataPoints[i].date, value: avg))
        }
        movingAverage = result
    }
}
