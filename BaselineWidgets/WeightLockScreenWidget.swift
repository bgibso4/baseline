import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Lock Screen Circular View

struct WeightCircularView: View {
    let entry: WeightTimelineEntry

    var body: some View {
        VStack(spacing: 0) {
            Text("WEIGHT")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.4)
                .opacity(0.8)

            if let weight = entry.currentWeight {
                // Whole number only for circular widget
                Text("\(Int(weight.rounded()))")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.4)
                Text(entry.unit)
                    .font(.system(size: 8, weight: .semibold))
                    .opacity(0.8)
                    .padding(.top, -2)
            } else {
                Text("--")
                    .font(.system(size: 20, weight: .bold))
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen Rectangular View

struct WeightRectangularView: View {
    let entry: WeightTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: dot + label
            HStack(spacing: 5) {
                Circle()
                    .frame(width: 5, height: 5)
                    .opacity(0.9)
                Text("Baseline")
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .opacity(0.75)
            }

            // Main row: weight + delta
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let weight = entry.currentWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(UnitConversion.formatWeight(weight, unit: entry.unit))
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.6)
                        Text(entry.unit)
                            .font(.system(size: 11, weight: .medium))
                            .opacity(0.8)
                    }

                    if let delta = computedDelta, abs(delta) >= 0.05 {
                        let sign = delta > 0 ? "+" : "\u{2212}"
                        Text("\(sign)\(String(format: "%.1f", abs(delta)))")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(0.9)
                    }
                } else {
                    Text("No data")
                        .font(.system(size: 15, weight: .medium))
                        .opacity(0.6)
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var computedDelta: Double? {
        guard let current = entry.currentWeight, let previous = entry.previousWeight else { return nil }
        return (current - previous).rounded(toPlaces: 1)
    }
}

// MARK: - Lock Screen Widget Configuration

struct WeightLockScreenWidget: Widget {
    let kind = "WeightLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeightWidgetProvider()) { entry in
            WeightLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Weight")
        .description("Weight on your lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct WeightLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WeightTimelineEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            WeightRectangularView(entry: entry)
        case .accessoryCircular:
            WeightCircularView(entry: entry)
        default:
            WeightCircularView(entry: entry)
        }
    }
}
