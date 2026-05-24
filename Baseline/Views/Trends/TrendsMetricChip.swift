import SwiftUI

/// The always-visible metric selector chip at the top of the Trends screen.
///
/// Presentational only: it renders the current metric (and compare badge when
/// active) and reports taps via `onTap`. The owning view holds the state and
/// presents the picker sheet.
struct TrendsMetricChip: View {
    let selectedMetric: TrendMetric
    let compareEnabled: Bool
    let secondaryMetric: TrendMetric?
    let previousPeriod: PreviousPeriodType?
    let secondaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if compareEnabled, let secondary = secondaryMetric {
                    // Dual-icon stack for metric compare
                    ZStack {
                        RoundedRectangle(cornerRadius: CadreRadius.sm)
                            .fill(CadreColors.cardElevated)
                            .frame(width: 28, height: 28)
                        Image(systemName: selectedMetric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.accent)
                            .offset(x: -3, y: -2)
                        Image(systemName: secondary.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(secondaryColor)
                            .offset(x: 5, y: 4)
                    }
                    Text("\(selectedMetric.displayName) \u{00B7} \(secondary.displayName)")
                        .font(CadreTypography.trendsMetricName)
                        .tracking(-0.1)
                        .foregroundStyle(CadreColors.textPrimary)
                        .lineLimit(1)
                } else if compareEnabled, let period = previousPeriod {
                    // Period compare chip
                    ZStack {
                        RoundedRectangle(cornerRadius: CadreRadius.sm)
                            .fill(CadreColors.cardElevated)
                            .frame(width: 28, height: 28)
                        Image(systemName: selectedMetric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.accent)
                    }
                    Text("\(selectedMetric.displayName) \u{00B7} vs \(period.rawValue)")
                        .font(CadreTypography.trendsMetricName)
                        .tracking(-0.1)
                        .foregroundStyle(CadreColors.textPrimary)
                        .lineLimit(1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: CadreRadius.sm)
                            .fill(CadreColors.cardElevated)
                            .frame(width: 28, height: 28)
                        Image(systemName: selectedMetric.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadreColors.accent)
                    }
                    Text(selectedMetric.displayName)
                        .font(CadreTypography.trendsMetricName)
                        .tracking(-0.1)
                        .foregroundStyle(CadreColors.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.Trends.metricPicker)
    }
}
