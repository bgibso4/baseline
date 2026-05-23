import SwiftUI

/// Reusable tile for the Body tab's 2-column grid.
///
/// Visual target: `docs/mockups/body-v1-2026-04-05.html` (Variant B tiles).
/// Layout: icon + label row, big value, optional delta indicator.
struct MetricTile: View {
    let sfSymbol: String
    let label: String
    let value: String
    let unit: String
    let delta: Delta?

    /// Whether the accent color is secondary (amber) vs primary (dusty blue).
    var isSecondaryAccent: Bool = false

    struct Delta {
        let text: String
        let direction: Direction

        enum Direction {
            /// Goal-favorable direction (e.g., BF% going down, muscle going up).
            case favorable
            /// Opposite of goal direction.
            case unfavorable
            /// No meaningful change.
            case flat
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon + label row (mockup .t-top)
            HStack(spacing: 8) {
                iconView
                Text(label.uppercased())
                    .font(CadreTypography.tileLabel)
                    .tracking(0.4)
                    .foregroundStyle(CadreColors.textSecondary)
                    .lineLimit(1)
                    // minimumScaleFactor prevents "text clipped" predictive audit
                    // failure at large Dynamic Type sizes when the tile is inside
                    // a fixed-column LazyVGrid. 0.6 accommodates long labels like
                    // "TOTAL BODY WATER" within a half-width tile column.
                    .minimumScaleFactor(0.6)
            }
            .padding(.bottom, 10)

            // Value (mockup .t-val, 24px/700)
            // lineLimit(1) + minimumScaleFactor prevent multi-line layout that
            // could cause the value text to overflow the tile's clipShape boundary,
            // which the accessibility "text clipped" audit would detect.
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(CadreTypography.tileValue)
                    .tracking(-0.6)
                    .foregroundStyle(CadreColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !unit.isEmpty {
                    Text(unit)
                        .font(CadreTypography.tileUnit)
                        .foregroundStyle(CadreColors.textSecondary)
                        .lineLimit(1)
                }
            }
            .lineLimit(1)

            // Delta (mockup .t-delta, 10px/600)
            if let delta {
                Text(delta.text)
                    .font(CadreTypography.tileDelta)
                    .foregroundStyle(deltaColor(delta.direction))
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        // clipShape removed: glassCard provides the rounded visual container.
        // Removing clipShape ensures visual text elements (even those hidden from
        // VoiceOver via .accessibilityElement(children:.ignore)) don't have their
        // accessibility frames touching the clip boundary, which triggers the
        // "text clipped" audit. Content padding (12pt horizontal, 13pt vertical)
        // keeps all text well within the tile's visual bounds.
        .glassCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tileAccessibilityLabel)
    }

    private var tileAccessibilityLabel: String {
        var parts = ["\(label): \(value)"]
        if !unit.isEmpty { parts[0] += " \(unit)" }
        if let delta { parts.append("change: \(delta.text)") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Private

    private var iconView: some View {
        Image(systemName: sfSymbol)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(isSecondaryAccent ? CadreColors.chartMovingAverage : CadreColors.accent)
            .frame(width: 22, height: 22)
            .background(CadreColors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func deltaColor(_ direction: Delta.Direction) -> Color {
        switch direction {
        case .favorable: return CadreColors.deltaDown   // accent dusty blue
        case .unfavorable: return CadreColors.deltaUp   // sage green
        case .flat: return CadreColors.textTertiary
        }
    }
}

/// Empty-state version of the tile (no data yet).
struct MetricTileEmpty: View {
    let sfSymbol: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CadreColors.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(CadreColors.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(label.uppercased())
                    .font(CadreTypography.tileLabel)
                    .tracking(0.4)
                    .foregroundStyle(CadreColors.textTertiary)
                    .lineLimit(1)
            }
            .padding(.bottom, 10)

            Text("No data")
                .font(CadreTypography.tileValue)
                .tracking(-0.6)
                .foregroundStyle(CadreColors.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

#Preview {
    VStack(spacing: 8) {
        HStack(spacing: 8) {
            MetricTile(
                sfSymbol: "drop.fill",
                label: "Body Fat",
                value: "17.2",
                unit: "%",
                delta: .init(text: "\u{2193} 0.4%", direction: .favorable),
                isSecondaryAccent: true
            )
            MetricTile(
                sfSymbol: "figure.strengthtraining.traditional",
                label: "Skeletal Muscle",
                value: "162.4",
                unit: "lb",
                delta: .init(text: "\u{2191} 1.2 lb", direction: .favorable)
            )
        }
        HStack(spacing: 8) {
            MetricTile(
                sfSymbol: "ruler",
                label: "Waist",
                value: "34.5",
                unit: "in",
                delta: .init(text: "\u{2193} 0.5\"", direction: .favorable)
            )
            MetricTileEmpty(sfSymbol: "heart", label: "Chest")
        }
    }
    .padding(22)
    .background(CadreColors.bg)
    .preferredColorScheme(.dark)
}
