import SwiftUI

/// Lightweight metric history — shows date + value rows for a single metric.
/// Used when tapping body comp or measurement tiles on the Body tab.
struct MetricHistoryView: View {
    let metricName: String
    let unit: String
    let entries: [(date: Date, value: String)]

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(CadreColors.textTertiary)
                    Text("No history yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            } else {
                List {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(DateFormatting.weekdayShort(entry.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(CadreColors.textSecondary)
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(entry.value)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(CadreColors.textPrimary)
                                if !unit.isEmpty {
                                    Text(unit)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(CadreColors.textTertiary)
                                }
                            }
                        }
                        .listRowBackground(CadreColors.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(metricName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
