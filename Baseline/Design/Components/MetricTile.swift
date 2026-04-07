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
            }
            .padding(.bottom, 10)

            // Value (mockup .t-val, 24px/700)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(CadreTypography.tileValue)
                    .tracking(-0.6)
                    .foregroundStyle(CadreColors.textPrimary)
                    .lineLimit(1)

                if !unit.isEmpty {
                    Text(unit)
                        .font(CadreTypography.tileUnit)
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }

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
        .background(CadreColors.card)
        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
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
        .background(CadreColors.card)
        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
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
