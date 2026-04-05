import SwiftUI

// MARK: - Colors
// Values are placeholders — refined during high-fidelity mockup phase.
// This file becomes the seed of CadreKit when Apex migrates to Swift.

enum CadreColors {
    // Backgrounds — locked neutrals from 2026-04-04 visual identity
    static let bg = Color(hex: "0B0B0E")
    static let card = Color(hex: "17171B")
    static let cardElevated = Color(hex: "1F1F24")

    // Text — locked neutrals
    static let textPrimary = Color(hex: "F2F3F5")
    static let textSecondary = Color(hex: "797B83")
    static let textTertiary = Color(hex: "494B52")

    // Divider
    static let divider = Color(hex: "2A2A30")

    // Accent — dusty blue (swappable token; amber + warm-gray in reserve)
    static let accent = Color(hex: "6B7B94")
    static let accentLight = Color(hex: "8B9AB0")

    // Semantic
    static let positive = Color(hex: "34C759")
    static let negative = Color(hex: "FF3B30")
    static let neutral = Color(hex: "8E8E9A")

    // Chart
    static let chartLine = Color(hex: "6B7B94")
    static let chartMovingAverage = Color(hex: "B89968")
    static let chartFill = Color(hex: "6B7B94").opacity(0.15)
    static let chartGrid = Color(hex: "2A2A30")
}

// MARK: - Spacing

enum CadreSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Typography

enum CadreTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let callout = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let footnote = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)

    // MARK: Now screen tokens
    // Sizes/weights/tracking sourced from
    // docs/mockups/today-APPROVED-variant-a-2026-04-04.html

    /// Giant hero number (`.weight-num`, 84px/700, letter-spacing -2.5px).
    /// Use with `.tracking(-2.5)` at the call site.
    static let weightHero = Font.system(size: 84, weight: .bold, design: .default)
    /// "lb"/"kg" suffix beside hero number (`.weight-num .unit`, 24px/500).
    static let weightUnit = Font.system(size: 24, weight: .medium)
    /// "Today" caption under hero number (`.today-label`, 13px/500).
    static let todayLabel = Font.system(size: 13, weight: .medium)
    /// 30D/90D/All segmented toggle (`.toggle .opt`, 12px/500).
    static let toggleOption = Font.system(size: 12, weight: .medium)
    /// LOWEST/AVERAGE/HIGHEST uppercase caption (`.stat .label`,
    /// 9px/600, 0.5px tracking, uppercase). Use with `.tracking(0.5)`.
    static let statLabel = Font.system(size: 9, weight: .semibold)
    /// Stat card numeric value (`.stat .value`, 18px/700).
    static let statValue = Font.system(size: 18, weight: .bold)
    /// Stat card unit suffix (`.stat .value .unit`, 10px/400).
    static let statUnit = Font.system(size: 10, weight: .regular)
    /// Primary "Weigh In" button (`.weigh-btn`, 16px/600, 0.3px tracking).
    /// Use with `.tracking(0.3)` at the call site.
    static let buttonLabel = Font.system(size: 16, weight: .semibold)

    /// Delta display (retained for other screens).
    static let deltaDisplay = Font.system(size: 17, weight: .medium, design: .rounded)

    /// Deprecated: superseded by `weightHero` (84pt) on the Now screen.
    /// Retained temporarily; remove once no longer referenced.
    @available(*, deprecated, message: "Use weightHero (84pt) — matches approved Now mockup.")
    static let weightDisplay = Font.system(size: 64, weight: .bold, design: .rounded)
}

// MARK: - Corner Radius

enum CadreRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
