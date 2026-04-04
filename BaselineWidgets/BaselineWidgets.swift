import WidgetKit
import SwiftUI

@main
struct BaselineWidgetBundle: WidgetBundle {
    var body: some Widget {
        BaselineWidgetPlaceholder()
    }
}

struct BaselineWidgetPlaceholder: Widget {
    let kind = "BaselineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("Baseline")
        }
        .configurationDisplayName("Weight")
        .description("Today's weight at a glance.")
    }
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) { completion(SimpleEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .atEnd))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}
