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

/// Metric group for the picker sheet.
enum TrendMetricGroup: String, CaseIterable {
    case core = "Core"
    case bodyComposition = "Body Composition"
    case segmentalLean = "Segmental Lean"
    case segmentalFat = "Segmental Fat"
    case measurements = "Measurements"
}

/// Selectable metric for the Trends chart.
enum TrendMetric: String, CaseIterable {
    // Core
    case weight = "Weight"
    case bodyFatPct = "Body Fat %"
    case skeletalMuscle = "Skeletal Muscle"
    case bmi = "BMI"
    case fatMass = "Fat Mass"

    // Body Composition
    case leanBodyMass = "Lean Body Mass"
    case totalBodyWater = "Total Body Water"
    case icw = "ICW"
    case ecw = "ECW"
    case dryLeanMass = "Dry Lean Mass"
    case bmr = "BMR"
    case inBodyScore = "InBody Score"

    // Segmental Lean
    case rightArmLean = "Right Arm (Lean)"
    case leftArmLean = "Left Arm (Lean)"
    case trunkLean = "Trunk (Lean)"
    case rightLegLean = "Right Leg (Lean)"
    case leftLegLean = "Left Leg (Lean)"

    // Segmental Fat
    case rightArmFat = "Right Arm (Fat)"
    case leftArmFat = "Left Arm (Fat)"
    case trunkFat = "Trunk (Fat)"
    case rightLegFat = "Right Leg (Fat)"
    case leftLegFat = "Left Leg (Fat)"

    // Measurements
    case waist = "Waist"
    case chest = "Chest"
    case neck = "Neck"
    case hips = "Hips"
    case armLeft = "Arm · L"
    case armRight = "Arm · R"
    case thighLeft = "Thigh · L"
    case thighRight = "Thigh · R"
    case calfLeft = "Calf · L"
    case calfRight = "Calf · R"

    var group: TrendMetricGroup {
        switch self {
        case .weight, .bodyFatPct, .skeletalMuscle, .bmi, .fatMass:
            return .core
        case .leanBodyMass, .totalBodyWater, .icw, .ecw, .dryLeanMass, .bmr, .inBodyScore:
            return .bodyComposition
        case .rightArmLean, .leftArmLean, .trunkLean, .rightLegLean, .leftLegLean:
            return .segmentalLean
        case .rightArmFat, .leftArmFat, .trunkFat, .rightLegFat, .leftLegFat:
            return .segmentalFat
        case .waist, .chest, .neck, .hips, .armLeft, .armRight, .thighLeft, .thighRight, .calfLeft, .calfRight:
            return .measurements
        }
    }

    var unit: String {
        let weightUnit = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        let lengthUnit = UserDefaults.standard.string(forKey: "lengthUnit") ?? "in"
        switch self {
        case .weight, .skeletalMuscle, .fatMass, .leanBodyMass, .dryLeanMass:
            return weightUnit
        case .bodyFatPct:
            return "%"
        case .bmi, .inBodyScore:
            return ""
        case .totalBodyWater, .icw, .ecw:
            return "L"
        case .bmr:
            return "kcal"
        case .rightArmLean, .leftArmLean, .trunkLean, .rightLegLean, .leftLegLean,
             .rightArmFat, .leftArmFat, .trunkFat, .rightLegFat, .leftLegFat:
            return weightUnit
        case .waist, .chest, .neck, .hips, .armLeft, .armRight, .thighLeft, .thighRight, .calfLeft, .calfRight:
            return lengthUnit
        }
    }

    /// User-facing display name. Spells out acronyms with abbreviation in parentheses.
    /// rawValue is kept short for data storage (goal metric keys).
    var displayName: String {
        switch self {
        case .icw: return "Intracellular Water (ICW)"
        case .ecw: return "Extracellular Water (ECW)"
        case .bmr: return "Basal Metabolic Rate (BMR)"
        case .skeletalMuscle: return "Skeletal Muscle Mass (SMM)"
        case .leanBodyMass: return "Lean Body Mass (LBM)"
        case .fatMass: return "Body Fat Mass"
        case .totalBodyWater: return "Total Body Water (TBW)"
        default: return rawValue
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass"
        case .bodyFatPct: return "drop.fill"
        case .skeletalMuscle: return "figure.strengthtraining.traditional"
        case .bmi: return "chart.bar"
        case .fatMass: return "scalemass"
        case .leanBodyMass: return "figure.stand"
        case .totalBodyWater: return "drop"
        case .icw: return "drop.halffull"
        case .ecw: return "drop.halffull"
        case .dryLeanMass: return "figure.stand"
        case .bmr: return "flame"
        case .inBodyScore: return "star"
        case .rightArmLean, .leftArmLean: return "figure.arms.open"
        case .trunkLean: return "figure.stand"
        case .rightLegLean, .leftLegLean: return "figure.walk"
        case .rightArmFat, .leftArmFat: return "figure.arms.open"
        case .trunkFat: return "figure.stand"
        case .rightLegFat, .leftLegFat: return "figure.walk"
        case .waist: return "ruler"
        case .chest: return "heart"
        case .neck: return "circle.dotted"
        case .hips: return "figure.stand"
        case .armLeft, .armRight: return "figure.arms.open"
        case .thighLeft, .thighRight: return "figure.walk"
        case .calfLeft, .calfRight: return "figure.run"
        }
    }

    /// Whether this metric is derived from scan data (as opposed to weight entries or tape measurements).
    var isScanDerived: Bool {
        switch self {
        case .weight: return false
        case .waist, .chest, .neck, .hips, .armLeft, .armRight, .thighLeft, .thighRight, .calfLeft, .calfRight:
            return false
        default:
            return true
        }
    }

    /// The corresponding MeasurementType for tape-based metrics, nil for non-measurement metrics.
    var measurementType: MeasurementType? {
        switch self {
        case .waist: return .waist
        case .chest: return .chest
        case .neck: return .neck
        case .hips: return .hips
        case .armLeft: return .armLeft
        case .armRight: return .armRight
        case .thighLeft: return .thighLeft
        case .thighRight: return .thighRight
        case .calfLeft: return .calfLeft
        case .calfRight: return .calfRight
        default: return nil
        }
    }
}

/// What the compare overlay shows: another metric, or the same metric from a prior period.
enum CompareMode: Equatable {
    case metric(TrendMetric)
    case previousPeriod(PreviousPeriodType)
}

enum PreviousPeriodType: String, CaseIterable {
    case lastMonth = "Last month"
    case lastYear = "Last year"

    /// Number of days to shift the prior window forward for date-alignment.
    var shiftDays: Int {
        switch self {
        case .lastMonth: return 30
        case .lastYear: return 365
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
    var secondaryMetric: TrendMetric?
    var compareMode: CompareMode?

    /// Right edge of the currently-viewed window. Defaults to now (latest
    /// data). Stepper buttons in TrendsView shift this backward/forward by
    /// `timeRange.days` so the user can browse historical windows without
    /// gesture-based scrolling. Resets to `Date()` whenever the user
    /// changes time range or metric.
    var windowEndDate: Date = Date()

    /// Generic data points for the currently selected metric.
    var dataPoints: [TrendDataPoint] = []
    var movingAverage: [MovingAveragePoint] = []

    /// Most recent data point for the selected metric across ALL time —
    /// independent of `windowEndDate`/`timeRange`. Used by the view so the
    /// hero stays meaningful when the user steps back into a window with
    /// no data ("data exists, just not here") instead of falling through
    /// to the cold-start empty state.
    var latestPoint: TrendDataPoint?

    /// Date of the earliest data point for the selected metric, across all
    /// time. Used to gate the backward stepper so we stop at the oldest
    /// window that still has data instead of letting the user wander into
    /// a forever-empty past.
    var earliestEntryDate: Date?

    /// Secondary metric data points (populated when compare is active).
    var secondaryDataPoints: [TrendDataPoint] = []

    /// Legacy accessor — weight entries (only populated when metric == .weight).
    var entries: [WeightEntry] = []

    var minValue: Double { dataPoints.map(\.value).min() ?? 0 }
    var maxValue: Double { dataPoints.map(\.value).max() ?? 0 }

    var secondaryMinValue: Double { secondaryDataPoints.map(\.value).min() ?? 0 }
    var secondaryMaxValue: Double { secondaryDataPoints.map(\.value).max() ?? 0 }

    /// Legacy aliases for weight-only tests.
    var minWeight: Double { minValue }
    var maxWeight: Double { maxValue }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Window navigation (#62 — Whoop-style stepper)

    /// Step the visible window backward (-1) or forward (+1) by exactly
    /// one `timeRange.days` chunk. No-op for `.all` (no chunking — the
    /// nav UI hides itself in that case). Caller is expected to call
    /// `refresh()` after.
    func stepWindow(by direction: Int) {
        guard let days = timeRange.days else { return }
        let shift = days * direction
        let cal = Calendar.current
        let proposed = cal.date(byAdding: .day, value: shift, to: windowEndDate) ?? windowEndDate
        // Cap at "today" — there's no point stepping into the future.
        let today = Date()
        windowEndDate = min(proposed, today)
    }

    /// True when the current window doesn't already include today, i.e.
    /// stepping forward will reveal newer data.
    var canStepForward: Bool {
        let cal = Calendar.current
        return cal.startOfDay(for: windowEndDate) < cal.startOfDay(for: Date())
    }

    /// True when stepping backward by one window-width would still land
    /// somewhere with data — i.e., the proposed earlier window's right
    /// edge still sits at or after the earliest known entry. Disabled
    /// once the user is already at the oldest window with data, so the
    /// stepper bottoms out instead of letting them wander into a
    /// permanently empty past.
    var canStepBackward: Bool {
        guard let earliest = earliestEntryDate else { return false }
        guard let days = timeRange.days else { return false }
        let cal = Calendar.current
        // Right edge of the proposed previous window:
        // current windowEndDate - days.
        let proposedEnd = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: windowEndDate)) ?? windowEndDate
        return cal.startOfDay(for: earliest) < proposedEnd.addingTimeInterval(86400)
    }

    /// Inclusive start of the current window (one `timeRange.days` chunk
    /// before the right edge). Returns nil for `.all` since there's no
    /// finite window in that mode.
    var windowStartDate: Date? {
        guard let days = timeRange.days else { return nil }
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: windowEndDate)
        return cal.date(byAdding: .day, value: -(days - 1), to: endDay)
    }

    /// Display label for the current window — "MAR 6 - APR 4, 26"
    /// matches Whoop's Trend View. Empty string for `.all`.
    var currentWindowLabel: String {
        guard let start = windowStartDate else { return "" }
        let end = Calendar.current.startOfDay(for: windowEndDate)
        let monthDay = DateFormatter()
        monthDay.dateFormat = "MMM d"
        let yearTwoDigit = DateFormatter()
        yearTwoDigit.dateFormat = "yy"
        let startStr = monthDay.string(from: start).uppercased()
        let endStr = monthDay.string(from: end).uppercased()
        let yearStr = yearTwoDigit.string(from: end)
        return "\(startStr) – \(endStr), \(yearStr)"
    }

    func refresh() {
        switch selectedMetric {
        case .weight:
            refreshWeight()

        // Core scan metrics
        case .bodyFatPct:
            refreshScanMetric { $0.bodyFatPct }
        case .skeletalMuscle:
            refreshScanMetric { UnitConversion.displayMass($0.skeletalMuscleMassKg).value }
        case .bmi:
            refreshScanMetric { $0.bmi }
        case .fatMass:
            refreshScanMetric { UnitConversion.displayMass($0.bodyFatMassKg).value }

        // Body Composition
        case .leanBodyMass:
            refreshOptionalScanMetric { $0.leanBodyMassKg.map { UnitConversion.displayMass($0).value } }
        case .totalBodyWater:
            refreshScanMetric { $0.totalBodyWaterL }
        case .icw:
            refreshOptionalScanMetric { $0.intracellularWaterL }
        case .ecw:
            refreshOptionalScanMetric { $0.extracellularWaterL }
        case .dryLeanMass:
            refreshOptionalScanMetric { $0.dryLeanMassKg.map { UnitConversion.displayMass($0).value } }
        case .bmr:
            refreshScanMetric { $0.basalMetabolicRate }
        case .inBodyScore:
            refreshOptionalScanMetric { $0.inBodyScore }

        // Segmental Lean
        case .rightArmLean:
            refreshOptionalScanMetric { $0.rightArmLeanKg.map { UnitConversion.displayMass($0).value } }
        case .leftArmLean:
            refreshOptionalScanMetric { $0.leftArmLeanKg.map { UnitConversion.displayMass($0).value } }
        case .trunkLean:
            refreshOptionalScanMetric { $0.trunkLeanKg.map { UnitConversion.displayMass($0).value } }
        case .rightLegLean:
            refreshOptionalScanMetric { $0.rightLegLeanKg.map { UnitConversion.displayMass($0).value } }
        case .leftLegLean:
            refreshOptionalScanMetric { $0.leftLegLeanKg.map { UnitConversion.displayMass($0).value } }

        // Segmental Fat
        case .rightArmFat:
            refreshOptionalScanMetric { $0.rightArmFatKg.map { UnitConversion.displayMass($0).value } }
        case .leftArmFat:
            refreshOptionalScanMetric { $0.leftArmFatKg.map { UnitConversion.displayMass($0).value } }
        case .trunkFat:
            refreshOptionalScanMetric { $0.trunkFatKg.map { UnitConversion.displayMass($0).value } }
        case .rightLegFat:
            refreshOptionalScanMetric { $0.rightLegFatKg.map { UnitConversion.displayMass($0).value } }
        case .leftLegFat:
            refreshOptionalScanMetric { $0.leftLegFatKg.map { UnitConversion.displayMass($0).value } }

        // Measurements (tape)
        case .waist, .chest, .neck, .hips, .armLeft, .armRight, .thighLeft, .thighRight, .calfLeft, .calfRight:
            refreshMeasurement()
        }

        calculateMovingAverage()
        refreshSecondary()
        refreshLatestPoint()
    }

    /// Fetch the most-recent value for the selected metric (ignoring the
    /// active window) and the earliest entry date for that metric. Cheap
    /// (`fetchLimit = 1` for weight/measurement, full reverse scan walk
    /// for scan-derived metrics until a populated field is found; earliest
    /// uses a single forward-sorted limit-1 fetch / first-populated walk).
    private func refreshLatestPoint() {
        let metric = selectedMetric

        if metric == .weight {
            var newest = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\WeightEntry.date, order: .reverse)])
            newest.fetchLimit = 1
            if let entry = (try? modelContext.fetch(newest))?.first {
                latestPoint = TrendDataPoint(
                    date: entry.date,
                    value: UnitConversion.displayWeight(entry.weight, storedUnit: entry.unit)
                )
            } else {
                latestPoint = nil
            }

            var oldest = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\WeightEntry.date, order: .forward)])
            oldest.fetchLimit = 1
            earliestEntryDate = (try? modelContext.fetch(oldest))?.first?.date
            return
        }

        if let measType = metric.measurementType {
            let typeRaw = measType.rawValue
            var newest = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.type == typeRaw },
                sortBy: [SortDescriptor(\Measurement.date, order: .reverse)]
            )
            newest.fetchLimit = 1
            if let m = (try? modelContext.fetch(newest))?.first {
                latestPoint = TrendDataPoint(
                    date: m.date,
                    value: UnitConversion.displayLength(m.valueCm).value
                )
            } else {
                latestPoint = nil
            }

            var oldest = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.type == typeRaw },
                sortBy: [SortDescriptor(\Measurement.date, order: .forward)]
            )
            oldest.fetchLimit = 1
            earliestEntryDate = (try? modelContext.fetch(oldest))?.first?.date
            return
        }

        // Scan-derived: walk newest-to-oldest, then oldest-to-newest, until
        // each direction yields a scan that has a value for this metric.
        let newestScans = FetchDescriptor<Scan>(sortBy: [SortDescriptor(\Scan.date, order: .reverse)])
        let scansNewestFirst = (try? modelContext.fetch(newestScans)) ?? []
        latestPoint = nil
        for scan in scansNewestFirst {
            guard let content = try? scan.decoded(),
                  case .inBody(let payload) = content else { continue }
            if let value = extractScanValue(for: metric, from: payload) {
                latestPoint = TrendDataPoint(date: scan.date, value: value)
                break
            }
        }

        earliestEntryDate = nil
        for scan in scansNewestFirst.reversed() {
            guard let content = try? scan.decoded(),
                  case .inBody(let payload) = content else { continue }
            if extractScanValue(for: metric, from: payload) != nil {
                earliestEntryDate = scan.date
                break
            }
        }
    }

    private func extractScanValue(for metric: TrendMetric, from payload: InBodyPayload) -> Double? {
        switch metric {
        case .bodyFatPct: return payload.bodyFatPct
        case .skeletalMuscle: return UnitConversion.displayMass(payload.skeletalMuscleMassKg).value
        case .bmi: return payload.bmi
        case .fatMass: return UnitConversion.displayMass(payload.bodyFatMassKg).value
        case .leanBodyMass: return payload.leanBodyMassKg.map { UnitConversion.displayMass($0).value }
        case .totalBodyWater: return payload.totalBodyWaterL
        case .icw: return payload.intracellularWaterL
        case .ecw: return payload.extracellularWaterL
        case .dryLeanMass: return payload.dryLeanMassKg.map { UnitConversion.displayMass($0).value }
        case .bmr: return payload.basalMetabolicRate
        case .inBodyScore: return payload.inBodyScore
        case .rightArmLean: return payload.rightArmLeanKg.map { UnitConversion.displayMass($0).value }
        case .leftArmLean: return payload.leftArmLeanKg.map { UnitConversion.displayMass($0).value }
        case .trunkLean: return payload.trunkLeanKg.map { UnitConversion.displayMass($0).value }
        case .rightLegLean: return payload.rightLegLeanKg.map { UnitConversion.displayMass($0).value }
        case .leftLegLean: return payload.leftLegLeanKg.map { UnitConversion.displayMass($0).value }
        case .rightArmFat: return payload.rightArmFatKg.map { UnitConversion.displayMass($0).value }
        case .leftArmFat: return payload.leftArmFatKg.map { UnitConversion.displayMass($0).value }
        case .trunkFat: return payload.trunkFatKg.map { UnitConversion.displayMass($0).value }
        case .rightLegFat: return payload.rightLegFatKg.map { UnitConversion.displayMass($0).value }
        case .leftLegFat: return payload.leftLegFatKg.map { UnitConversion.displayMass($0).value }
        default: return nil
        }
    }

    /// Loads data for the secondary compare overlay.
    private func refreshSecondary() {
        // Derive compareMode from secondaryMetric for backwards compat
        let mode = compareMode ?? secondaryMetric.map { CompareMode.metric($0) }

        guard let mode else {
            secondaryDataPoints = []
            return
        }

        switch mode {
        case .metric(let metric):
            refreshSecondaryMetric(metric)
        case .previousPeriod(let period):
            refreshPreviousPeriod(period)
        }
    }

    /// Load a different metric as the secondary series.
    private func refreshSecondaryMetric(_ metric: TrendMetric) {
        // Temporarily swap selectedMetric to reuse existing refresh logic
        let primary = selectedMetric
        let primaryData = dataPoints
        let primaryMA = movingAverage
        let primaryEntries = entries

        selectedMetric = metric
        switch metric {
        case .weight: refreshWeight()
        case .bodyFatPct: refreshScanMetric { $0.bodyFatPct }
        case .skeletalMuscle: refreshScanMetric { UnitConversion.displayMass($0.skeletalMuscleMassKg).value }
        case .bmi: refreshScanMetric { $0.bmi }
        case .fatMass: refreshScanMetric { UnitConversion.displayMass($0.bodyFatMassKg).value }
        case .leanBodyMass: refreshOptionalScanMetric { $0.leanBodyMassKg.map { UnitConversion.displayMass($0).value } }
        case .totalBodyWater: refreshScanMetric { $0.totalBodyWaterL }
        case .icw: refreshOptionalScanMetric { $0.intracellularWaterL }
        case .ecw: refreshOptionalScanMetric { $0.extracellularWaterL }
        case .dryLeanMass: refreshOptionalScanMetric { $0.dryLeanMassKg.map { UnitConversion.displayMass($0).value } }
        case .bmr: refreshScanMetric { $0.basalMetabolicRate }
        case .inBodyScore: refreshOptionalScanMetric { $0.inBodyScore }
        case .rightArmLean: refreshOptionalScanMetric { $0.rightArmLeanKg.map { UnitConversion.displayMass($0).value } }
        case .leftArmLean: refreshOptionalScanMetric { $0.leftArmLeanKg.map { UnitConversion.displayMass($0).value } }
        case .trunkLean: refreshOptionalScanMetric { $0.trunkLeanKg.map { UnitConversion.displayMass($0).value } }
        case .rightLegLean: refreshOptionalScanMetric { $0.rightLegLeanKg.map { UnitConversion.displayMass($0).value } }
        case .leftLegLean: refreshOptionalScanMetric { $0.leftLegLeanKg.map { UnitConversion.displayMass($0).value } }
        case .rightArmFat: refreshOptionalScanMetric { $0.rightArmFatKg.map { UnitConversion.displayMass($0).value } }
        case .leftArmFat: refreshOptionalScanMetric { $0.leftArmFatKg.map { UnitConversion.displayMass($0).value } }
        case .trunkFat: refreshOptionalScanMetric { $0.trunkFatKg.map { UnitConversion.displayMass($0).value } }
        case .rightLegFat: refreshOptionalScanMetric { $0.rightLegFatKg.map { UnitConversion.displayMass($0).value } }
        case .leftLegFat: refreshOptionalScanMetric { $0.leftLegFatKg.map { UnitConversion.displayMass($0).value } }
        case .waist, .chest, .neck, .hips, .armLeft, .armRight, .thighLeft, .thighRight, .calfLeft, .calfRight:
            refreshMeasurement()
        }

        secondaryDataPoints = dataPoints

        // Restore primary
        selectedMetric = primary
        dataPoints = primaryData
        movingAverage = primaryMA
        entries = primaryEntries
    }

    /// Load the same metric from a prior period, shifting dates forward to align.
    private func refreshPreviousPeriod(_ period: PreviousPeriodType) {
        let calendar = Calendar.current
        let shiftDays = period.shiftDays

        // Save current state
        let primary = selectedMetric
        let primaryData = dataPoints
        let primaryMA = movingAverage
        let primaryEntries = entries
        let primaryTimeRange = timeRange

        // Temporarily set time range to load the prior window.
        // We load "All" data and then filter to the prior window manually,
        // because the refresh methods filter based on timeRange relative to today.
        timeRange = .all
        refresh_primary_only()

        // Now dataPoints has ALL data for this metric. Filter to the prior period.
        let currentEnd = calendar.startOfDay(for: Date())
        let currentStart: Date
        if let days = primaryTimeRange.days {
            currentStart = calendar.date(byAdding: .day, value: -days, to: currentEnd)!
        } else {
            // "All" range — use the earliest primary data point as reference
            currentStart = primaryData.first?.date ?? currentEnd
        }

        let priorEnd = currentStart
        let priorStart = calendar.date(byAdding: .day, value: -shiftDays, to: priorEnd)!

        // Filter to the prior window and shift dates forward
        let priorPoints = dataPoints.compactMap { point -> TrendDataPoint? in
            guard point.date >= priorStart && point.date < priorEnd else { return nil }
            let shifted = calendar.date(byAdding: .day, value: shiftDays, to: point.date) ?? point.date
            return TrendDataPoint(date: shifted, value: point.value)
        }

        secondaryDataPoints = priorPoints

        // Restore
        selectedMetric = primary
        dataPoints = primaryData
        movingAverage = primaryMA
        entries = primaryEntries
        timeRange = primaryTimeRange
    }

    /// Refresh just the primary metric data (no secondary, no MA) — used by previousPeriod.
    private func refresh_primary_only() {
        switch selectedMetric {
        case .weight: refreshWeight()
        case .bodyFatPct: refreshScanMetric { $0.bodyFatPct }
        case .skeletalMuscle: refreshScanMetric { UnitConversion.displayMass($0.skeletalMuscleMassKg).value }
        case .bmi: refreshScanMetric { $0.bmi }
        case .fatMass: refreshScanMetric { UnitConversion.displayMass($0.bodyFatMassKg).value }
        case .leanBodyMass: refreshOptionalScanMetric { $0.leanBodyMassKg.map { UnitConversion.displayMass($0).value } }
        case .totalBodyWater: refreshScanMetric { $0.totalBodyWaterL }
        case .icw: refreshOptionalScanMetric { $0.intracellularWaterL }
        case .ecw: refreshOptionalScanMetric { $0.extracellularWaterL }
        case .dryLeanMass: refreshOptionalScanMetric { $0.dryLeanMassKg.map { UnitConversion.displayMass($0).value } }
        case .bmr: refreshScanMetric { $0.basalMetabolicRate }
        case .inBodyScore: refreshOptionalScanMetric { $0.inBodyScore }
        case .rightArmLean: refreshOptionalScanMetric { $0.rightArmLeanKg.map { UnitConversion.displayMass($0).value } }
        case .leftArmLean: refreshOptionalScanMetric { $0.leftArmLeanKg.map { UnitConversion.displayMass($0).value } }
        case .trunkLean: refreshOptionalScanMetric { $0.trunkLeanKg.map { UnitConversion.displayMass($0).value } }
        case .rightLegLean: refreshOptionalScanMetric { $0.rightLegLeanKg.map { UnitConversion.displayMass($0).value } }
        case .leftLegLean: refreshOptionalScanMetric { $0.leftLegLeanKg.map { UnitConversion.displayMass($0).value } }
        case .rightArmFat: refreshOptionalScanMetric { $0.rightArmFatKg.map { UnitConversion.displayMass($0).value } }
        case .leftArmFat: refreshOptionalScanMetric { $0.leftArmFatKg.map { UnitConversion.displayMass($0).value } }
        case .trunkFat: refreshOptionalScanMetric { $0.trunkFatKg.map { UnitConversion.displayMass($0).value } }
        case .rightLegFat: refreshOptionalScanMetric { $0.rightLegFatKg.map { UnitConversion.displayMass($0).value } }
        case .leftLegFat: refreshOptionalScanMetric { $0.leftLegFatKg.map { UnitConversion.displayMass($0).value } }
        case .waist, .chest, .neck, .hips, .armLeft, .armRight, .thighLeft, .thighRight, .calfLeft, .calfRight:
            refreshMeasurement()
        }
    }

    // MARK: - Weight

    private func refreshWeight() {
        let sort = [SortDescriptor(\WeightEntry.date, order: .forward)]

        if let days = timeRange.days {
            let cal = Calendar.current
            let endDate = cal.startOfDay(for: windowEndDate).addingTimeInterval(86400)
            let startDate = cal.date(byAdding: .day, value: -days, to: endDate)!
            let descriptor = FetchDescriptor<WeightEntry>(
                predicate: #Predicate { $0.date > startDate && $0.date < endDate },
                sortBy: sort
            )
            entries = (try? modelContext.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<WeightEntry>(sortBy: sort)
            entries = (try? modelContext.fetch(descriptor)) ?? []
        }

        dataPoints = entries.map { entry in
            TrendDataPoint(date: entry.date, value: UnitConversion.displayWeight(entry.weight, storedUnit: entry.unit))
        }
    }

    // MARK: - Scan-derived metrics

    private func refreshScanMetric(extract: (InBodyPayload) -> Double) {
        entries = []
        let sort = [SortDescriptor(\Scan.date, order: .forward)]

        let scans: [Scan]
        if let days = timeRange.days {
            let cal = Calendar.current
            let endDate = cal.startOfDay(for: windowEndDate).addingTimeInterval(86400)
            let startDate = cal.date(byAdding: .day, value: -days, to: endDate)!
            let descriptor = FetchDescriptor<Scan>(
                predicate: #Predicate { $0.date > startDate && $0.date < endDate },
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

    // MARK: - Optional scan-derived metrics

    private func refreshOptionalScanMetric(extract: (InBodyPayload) -> Double?) {
        entries = []
        let sort = [SortDescriptor(\Scan.date, order: .forward)]

        let scans: [Scan]
        if let days = timeRange.days {
            let cal = Calendar.current
            let endDate = cal.startOfDay(for: windowEndDate).addingTimeInterval(86400)
            let startDate = cal.date(byAdding: .day, value: -days, to: endDate)!
            let descriptor = FetchDescriptor<Scan>(
                predicate: #Predicate { $0.date > startDate && $0.date < endDate },
                sortBy: sort
            )
            scans = (try? modelContext.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<Scan>(sortBy: sort)
            scans = (try? modelContext.fetch(descriptor)) ?? []
        }

        dataPoints = scans.compactMap { scan in
            guard let content = try? scan.decoded(),
                  case .inBody(let payload) = content,
                  let value = extract(payload) else { return nil }
            return TrendDataPoint(date: scan.date, value: value)
        }
    }

    // MARK: - Tape measurements (generic)

    private func refreshMeasurement() {
        entries = []
        guard let measType = selectedMetric.measurementType else {
            dataPoints = []
            return
        }
        let sort = [SortDescriptor(\Measurement.date, order: .forward)]
        let typeRaw = measType.rawValue

        let measurements: [Measurement]
        if let days = timeRange.days {
            let cal = Calendar.current
            let endDate = cal.startOfDay(for: windowEndDate).addingTimeInterval(86400)
            let startDate = cal.date(byAdding: .day, value: -days, to: endDate)!
            let descriptor = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.type == typeRaw && $0.date > startDate && $0.date < endDate },
                sortBy: sort
            )
            measurements = (try? modelContext.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.type == typeRaw },
                sortBy: sort
            )
            measurements = (try? modelContext.fetch(descriptor)) ?? []
        }

        dataPoints = measurements.map { m in
            TrendDataPoint(date: m.date, value: UnitConversion.displayLength(m.valueCm).value)
        }
    }

    // MARK: - Available metrics (only those with data)

    /// Returns metrics that have at least one data point, grouped by category.
    func computeAvailableMetrics() -> [TrendMetric] {
        var available: [TrendMetric] = []

        // Check weight
        var weightDescriptor = FetchDescriptor<WeightEntry>()
        weightDescriptor.fetchLimit = 1
        let hasWeight = ((try? modelContext.fetch(weightDescriptor))?.isEmpty == false)
        if hasWeight { available.append(.weight) }

        // Check scans — decode first scan to see which optional fields exist
        let scanDescriptor = FetchDescriptor<Scan>(sortBy: [SortDescriptor(\Scan.date, order: .reverse)])
        let scans = (try? modelContext.fetch(scanDescriptor)) ?? []
        if !scans.isEmpty {
            // Always-present scan metrics
            available.append(contentsOf: [.bodyFatPct, .skeletalMuscle, .bmi, .fatMass, .totalBodyWater, .bmr])

            // Check optional fields across all scans
            var hasField: [TrendMetric: Bool] = [:]
            let optionalMetrics: [(TrendMetric, (InBodyPayload) -> Double?)] = [
                (.leanBodyMass, { $0.leanBodyMassKg }),
                (.icw, { $0.intracellularWaterL }),
                (.ecw, { $0.extracellularWaterL }),
                (.dryLeanMass, { $0.dryLeanMassKg }),
                (.inBodyScore, { $0.inBodyScore }),
                (.rightArmLean, { $0.rightArmLeanKg }),
                (.leftArmLean, { $0.leftArmLeanKg }),
                (.trunkLean, { $0.trunkLeanKg }),
                (.rightLegLean, { $0.rightLegLeanKg }),
                (.leftLegLean, { $0.leftLegLeanKg }),
                (.rightArmFat, { $0.rightArmFatKg }),
                (.leftArmFat, { $0.leftArmFatKg }),
                (.trunkFat, { $0.trunkFatKg }),
                (.rightLegFat, { $0.rightLegFatKg }),
                (.leftLegFat, { $0.leftLegFatKg }),
            ]

            for scan in scans {
                guard let content = try? scan.decoded(),
                      case .inBody(let payload) = content else { continue }
                for (metric, extractor) in optionalMetrics {
                    if hasField[metric] != true && extractor(payload) != nil {
                        hasField[metric] = true
                    }
                }
                // Early exit if all found
                if hasField.count == optionalMetrics.count { break }
            }

            for (metric, _) in optionalMetrics where hasField[metric] == true {
                available.append(metric)
            }
        }

        // Check measurements
        let measurementMetrics: [TrendMetric] = [.waist, .chest, .neck, .hips, .armLeft, .armRight, .thighLeft, .thighRight, .calfLeft, .calfRight]
        for metric in measurementMetrics {
            guard let measType = metric.measurementType else { continue }
            let typeRaw = measType.rawValue
            let descriptor = FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.type == typeRaw },
                sortBy: [SortDescriptor(\Measurement.date)]
            )
            if let results = try? modelContext.fetch(descriptor), !results.isEmpty {
                available.append(metric)
            }
        }

        // Sort by the canonical allCases order
        let order = Dictionary(uniqueKeysWithValues: TrendMetric.allCases.enumerated().map { ($0.element, $0.offset) })
        available.sort { (order[$0] ?? 0) < (order[$1] ?? 0) }

        return available
    }

    // MARK: - Moving Average

    /// Smoothing window (in samples) for the trend line. Scales with the
    /// number of data points rather than the picker time range, so a
    /// sparse 6M view (e.g., one InBody scan a month) gets light smoothing
    /// while a dense 6M view (daily weights) gets heavy smoothing. Same
    /// dataset-count axis governs `showRawLine` / `showRawDots` so all
    /// density decisions move together.
    var movingAverageWindow: Int {
        let count = dataPoints.count
        switch count {
        case ..<60: return 7
        case 60..<200: return 14
        default: return 30
        }
    }

    /// Whether to render the raw daily line behind the smoothed trend.
    /// Always shown — the line itself is what carries the actual data;
    /// the smoothed trend is interpretation. Kept as a property so a
    /// future density rule (e.g., huge datasets) can opt out without
    /// changing call sites.
    var showRawLine: Bool {
        true
    }

    /// Whether to render dots on each raw datapoint. Hidden once you can
    /// no longer count individual marks — beyond that they stop being
    /// useful anchors and turn into visual noise. The connecting line
    /// stays visible at all densities so the data itself never disappears.
    var showRawDots: Bool {
        dataPoints.count <= 60
    }

    /// Centered moving average. Trailing MA visibly lags the data by
    /// roughly `window/2` days (most obvious on the 30-day window at Y/All
    /// where the trend line sits a full two weeks behind the actual data).
    /// Centering removes the phase shift — the smoothed value at index `i`
    /// is the mean of samples symmetric around `i`. At the edges (where
    /// there's no future data for the leading half, or no past data for
    /// the trailing half) we shrink the window to whatever's available, so
    /// every data point still gets a smoothed value.
    private func calculateMovingAverage() {
        let window = movingAverageWindow
        guard dataPoints.count >= window else {
            movingAverage = []
            return
        }

        let half = window / 2
        var result: [MovingAveragePoint] = []
        for i in 0..<dataPoints.count {
            let start = max(0, i - half)
            let end = min(dataPoints.count - 1, i + half)
            let slice = dataPoints[start...end]
            let avg = slice.map(\.value).reduce(0, +) / Double(slice.count)
            result.append(MovingAveragePoint(date: dataPoints[i].date, value: avg))
        }
        movingAverage = result
    }
}
