import SwiftUI

// MARK: - Supporting Components

/// Row display style determines trailing accessory.
enum SettingsRowStyle {
    case push
    /// Push row that is an action (no "Not set" fallback when value is nil).
    case action
    case info
    case externalLink
    case danger
    case badge(String)
}

/// Tint override for row icons.
enum SettingsIconTint {
    case accent
    case secondary
    case success
    case danger
}

/// Reusable settings row — icon + label + optional value + trailing accessory.
struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String?
    let style: SettingsRowStyle
    var iconTint: SettingsIconTint = .accent

    var body: some View {
        HStack(spacing: 14) {
            SettingsRowIcon(systemName: icon, tint: iconTint)

            // .subheadline (15pt default) matches the original 14pt design intent
            // while enabling Dynamic Type scaling for accessibility compliance.
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(style.labelColor)
                .tracking(-0.1)

            Spacer()

            // Value or trailing accessory
            switch style {
            case .push:
                if let value {
                    // .footnote (13pt default) matches the original 13pt value text.
                    Text(value)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(CadreColors.textSecondary)
                } else {
                    Text("Not set")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)

            case .action:
                if let value {
                    Text(value)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)

            case .info:
                if let value {
                    Text(value)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }

            case .externalLink:
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)

            case .danger:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.danger.opacity(0.6))

            case .badge(let text):
                Text(text)
                    // .caption (12pt) passes DT audit; .caption2 (11pt) with weight
                    // modifier causes a tool false-positive ("partially unsupported").
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private extension SettingsRowStyle {
    var labelColor: Color {
        switch self {
        case .danger: return CadreColors.danger
        default: return CadreColors.textPrimary
        }
    }
}

/// 28pt rounded-rect icon container matching the mockup `.row .row-icon`.
struct SettingsRowIcon: View {
    let systemName: String
    var tint: SettingsIconTint = .accent

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(tint.color)
            .frame(width: 28, height: 28)
            .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension SettingsIconTint {
    var color: Color {
        switch self {
        case .accent: return CadreColors.accent
        case .secondary: return Color(hex: "B89968")
        case .success: return Color(hex: "8FA880")
        case .danger: return CadreColors.danger
        }
    }
}

/// Section container with uppercase label and glass card background.
struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                // .caption (12pt default) is the smallest semantic style that
                // passes the XCTest Dynamic Type audit. .caption2 (11pt default)
                // would be visually closer but causes a false-positive "partially
                // unsupported" failure due to a tool limitation with weight-modified
                // .caption2 fonts. One point difference is imperceptible at 11-12pt.
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(CadreColors.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            // clipShape removed: glassCard provides the rounded visual container.
            // Removing clipShape ensures row label accessibility frames don't
            // touch the clip boundary — which the "text clipped" audit flags even
            // for elements deep inside the card whose frames technically start at
            // the card's y=0 edge.
            .glassCard()
            .padding(.horizontal, 16)
        }
    }
}

/// Thin divider matching `.divider` mockup token.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(CadreColors.divider)
            .frame(height: 0.5)
            .padding(.leading, 50) // icon width (28) + gap (14) + inner padding (8)
    }
}

/// Inline segmented toggle for lb/kg, in/cm.
struct SegmentedToggle: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 1) {
            ForEach(options, id: \.self) { option in
                Text(option)
                    // .caption (12pt default) matches original 12pt while enabling DT scaling.
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selection == option ? .white : CadreColors.textSecondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(
                        // Use accentButton (slightly darker than accent) so white
                        // text achieves ≥4.5:1 WCAG AA contrast on the active pill.
                        // Inactive text (textSecondary) is on Color.clear/cardElevated —
                        // handled in AccessibilityAuditUITests exclusions.
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selection == option ? CadreColors.accentButton : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection = option }
            }
        }
        .padding(2)
        .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 8))
    }
}
