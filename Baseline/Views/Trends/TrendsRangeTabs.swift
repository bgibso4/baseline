import SwiftUI

/// Segmented M / 6M / Y / All range selector under the metric chip.
///
/// Presentational only: highlights the active range and reports selection via
/// `onSelect`. The owning view performs the range change, window reset, and
/// refresh.
struct TrendsRangeTabs: View {
    let selected: TimeRange
    let onSelect: (TimeRange) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                let active = selected == range
                Text(range.rawValue)
                    .font(CadreTypography.trendsRangeTab)
                    .foregroundStyle(active ? CadreColors.textPrimary : CadreColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(active ? CadreColors.cardElevated : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(range)
                    }
            }
        }
        .padding(3)
        .glassCard(cornerRadius: 10)
    }
}
