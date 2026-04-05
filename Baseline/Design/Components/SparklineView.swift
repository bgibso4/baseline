import SwiftUI
import Charts

/// Minimal line+area sparkline over a series of weight entries.
/// Used by widgets and supplemental views; the Today screen uses the arc indicator instead.
struct SparklineView: View {
    let weights: [WeightEntry]

    var body: some View {
        if weights.count >= 2 {
            Chart(weights, id: \.id) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(CadreColors.chartLine)

                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(CadreColors.chartFill)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
        } else {
            Text("Not enough data")
                .font(CadreTypography.caption)
                .foregroundStyle(CadreColors.textTertiary)
        }
    }
}
