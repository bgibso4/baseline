import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Shared Constants

private let appGroupID = "group.com.cadre.baseline"

private let widgetBg = Color(red: 0.043, green: 0.043, blue: 0.055)        // #0B0B0E
private let widgetCard = Color(red: 0.090, green: 0.090, blue: 0.106)      // #17171B
private let widgetTextPrimary = Color(red: 0.949, green: 0.953, blue: 0.961) // #F2F3F5
private let widgetTextSecondary = Color(red: 0.475, green: 0.482, blue: 0.514) // #797B83
private let widgetTextTertiary = Color(red: 0.286, green: 0.294, blue: 0.322) // #494B52
private let widgetAccent = Color(red: 0.420, green: 0.482, blue: 0.580)    // #6B7B94
private let widgetDivider = Color(red: 0.165, green: 0.165, blue: 0.188)   // #2A2A30

// MARK: - Timeline Entry

struct WeightTimelineEntry: TimelineEntry {
    let date: Date
    let currentWeight: Double?
    let previousWeight: Double?
    let unit: String
}

// MARK: - Timeline Provider

struct WeightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeightTimelineEntry {
        WeightTimelineEntry(date: .now, currentWeight: 197.4, previousWeight: 197.7, unit: "lb")
    }

    func getSnapshot(in context: Context, completion: @escaping (WeightTimelineEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightTimelineEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh at the start of the next day
        let nextMidnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func fetchEntry() -> WeightTimelineEntry {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Baseline.store") else {
            return WeightTimelineEntry(date: .now, currentWeight: nil, previousWeight: nil, unit: "lb")
        }

        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: WeightEntry.self, configurations: config)
            let context = ModelContext(container)

            var descriptor = FetchDescriptor<WeightEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 2

            let entries = try context.fetch(descriptor)
            let current = entries.first
            let previous = entries.count > 1 ? entries[1] : nil

            return WeightTimelineEntry(
                date: .now,
                currentWeight: current?.weight,
                previousWeight: previous?.weight,
                unit: current?.unit ?? "lb"
            )
        } catch {
            return WeightTimelineEntry(date: .now, currentWeight: nil, previousWeight: nil, unit: "lb")
        }
    }
}

// MARK: - Small Widget View

struct WeightWidgetSmallView: View {
    let entry: WeightTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top label row
            HStack(spacing: 5) {
                Circle()
                    .fill(widgetAccent)
                    .frame(width: 6, height: 6)
                Text("Today")
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(widgetTextTertiary)
            }

            // Hero weight
            if let weight = entry.currentWeight {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(UnitConversion.formatWeight(weight, unit: entry.unit))
                            .font(.system(size: 42, weight: .bold))
                            .tracking(-1.1)
                            .foregroundStyle(widgetTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(entry.unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(widgetTextSecondary)
                    }

                    if let delta = computedDelta {
                        Text(deltaString(delta))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(widgetAccent)
                    }
                }
            } else {
                Text("No data")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(widgetTextTertiary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(widgetBg, for: .widget)
    }

    private var computedDelta: Double? {
        guard let current = entry.currentWeight, let previous = entry.previousWeight else { return nil }
        return (current - previous).rounded(toPlaces: 1)
    }

    private func deltaString(_ delta: Double) -> String {
        if abs(delta) < 0.05 { return "Same as yesterday" }
        let sign = delta > 0 ? "+" : "\u{2212}"
        return "\(sign)\(String(format: "%.1f", abs(delta))) from yesterday"
    }
}

// MARK: - Medium Widget View

struct WeightWidgetMediumView: View {
    let entry: WeightTimelineEntry

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                // Top label row
                HStack(spacing: 5) {
                    Circle()
                        .fill(widgetAccent)
                        .frame(width: 6, height: 6)
                    Text("Today")
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(widgetTextTertiary)
                    Spacer()
                    Text(dateString)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(widgetTextTertiary)
                }

                // Hero weight
                if let weight = entry.currentWeight {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(UnitConversion.formatWeight(weight, unit: entry.unit))
                                .font(.system(size: 48, weight: .bold))
                                .tracking(-1.3)
                                .foregroundStyle(widgetTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(entry.unit)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(widgetTextSecondary)
                        }

                        if let delta = computedDelta {
                            Text(compactDeltaString(delta))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(widgetAccent)
                        }
                    }
                } else {
                    Text("No data yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(widgetTextTertiary)
                }

                Spacer(minLength: 0)
            }

            // Sparkline placeholder area
            // Full sparkline requires historical data query — stubbed with accent line
            if entry.currentWeight != nil {
                GeometryReader { geo in
                    Path { path in
                        let h = geo.size.height
                        let w = geo.size.width
                        // Simple placeholder diagonal line
                        path.move(to: CGPoint(x: 0, y: h * 0.3))
                        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
                        path.addLine(to: CGPoint(x: w, y: h * 0.7))
                    }
                    .stroke(widgetAccent, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(widgetBg, for: .widget)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: entry.date)
    }

    private var computedDelta: Double? {
        guard let current = entry.currentWeight, let previous = entry.previousWeight else { return nil }
        return (current - previous).rounded(toPlaces: 1)
    }

    private func compactDeltaString(_ delta: Double) -> String {
        if abs(delta) < 0.05 { return "No change" }
        let sign = delta > 0 ? "+" : "\u{2212}"
        return "\(sign)\(String(format: "%.1f", abs(delta)))"
    }
}

// MARK: - Widget Configuration

struct WeightWidget: Widget {
    let kind = "WeightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeightWidgetProvider()) { entry in
            WeightWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weight")
        .description("Today's weight at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Use environment to select the right view
struct WeightWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WeightTimelineEntry

    var body: some View {
        switch family {
        case .systemMedium:
            WeightWidgetMediumView(entry: entry)
        default:
            WeightWidgetSmallView(entry: entry)
        }
    }
}
