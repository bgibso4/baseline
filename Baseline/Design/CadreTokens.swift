import SwiftUI

// MARK: - Colors
// Values are placeholders — refined during high-fidelity mockup phase.
// This file becomes the seed of CadreKit when Apex migrates to Swift.

enum CadreColors {
    // Backgrounds
    static let bg = Color(hex: "0A0A0F")
    static let card = Color(hex: "16161F")
    static let cardElevated = Color(hex: "1E1E2A")

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E9A")
    static let textTertiary = Color(hex: "5A5A66")

    // Accent
    static let accent = Color(hex: "6C63FF")
    static let accentLight = Color(hex: "8B84FF")

    // Semantic
    static let positive = Color(hex: "34C759")
    static let negative = Color(hex: "FF3B30")
    static let neutral = Color(hex: "8E8E9A")

    // Chart
    static let chartLine = Color(hex: "6C63FF")
    static let chartMovingAverage = Color(hex: "FF9F0A")
    static let chartFill = Color(hex: "6C63FF").opacity(0.15)
    static let chartGrid = Color(hex: "2A2A36")
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

    // Weight display — the big number on Today screen
    static let weightDisplay = Font.system(size: 64, weight: .bold, design: .rounded)
    static let weightUnit = Font.system(size: 20, weight: .medium, design: .rounded)
    static let deltaDisplay = Font.system(size: 17, weight: .medium, design: .rounded)
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
