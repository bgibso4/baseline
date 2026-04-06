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
                        HStack(spacing: 16) {
                            // Date block — large day number + month-year below
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dayNumber(entry.date))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(CadreColors.textPrimary)
                                Text(monthYear(entry.date))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(CadreColors.textSecondary)
                            }
                            .frame(width: 60, alignment: .leading)

                            Spacer()

                            // Value + unit on the right
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(entry.value)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(CadreColors.textPrimary)
                                if !unit.isEmpty {
                                    Text(unit)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(CadreColors.textSecondary)
                                }
                            }
                        }
                        .listRowBackground(CadreColors.card)
                        .listRowInsets(EdgeInsets(top: 12, leading: CadreSpacing.md, bottom: 12, trailing: CadreSpacing.md))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(metricName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Date Helpers

    private func dayNumber(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private func monthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}
