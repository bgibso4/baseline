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

    // Glass card — translucent version of card for use over gradients
    static let cardGlass = Color(hex: "17171B").opacity(0.75)
    static let cardBorder = Color.white.opacity(0.06)

    // Divider
    static let divider = Color(hex: "2A2A30")

    // Background gradient — subtle cool depth
    // Radial glow: a whisper of dusty blue bleeding into the charcoal
    static let bgGradientCenter = Color(hex: "111520")  // barely-blue charcoal
    static let bgGradientEdge = Color(hex: "0B0B0E")    // == bg, pure charcoal

    // Accent — dusty blue (swappable token; amber + warm-gray in reserve)
    static let accent = Color(hex: "6B7B94")
    static let accentLight = Color(hex: "8B9AB0")

    // Semantic
    static let positive = Color(hex: "34C759")
    static let negative = Color(hex: "FF3B30")
    static let neutral = Color(hex: "8E8E9A")

    // Delta direction — mockup body-v1 uses `--up: #8FA880` (sage green)
    // and `--down: #6B7B94` (accent/dusty blue). "down" == accent for lowerIsBetter.
    static let deltaUp = Color(hex: "8FA880")
    static let deltaDown = Color(hex: "6B7B94")

    // Danger — settings delete, destructive actions (mockup --danger: #C17171)
    static let danger = Color(hex: "C17171")

    // Success — connected status badges (mockup --success: #8FA880)
    static let success = Color(hex: "8FA880")

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

    /// Horizontal inset for sheet content — matches mockup padding (22pt)
    static let sheetHorizontal: CGFloat = 22
}

// MARK: - Typography

enum CadreTypography {
    // MARK: - Helpers

    /// Scaled font: uses the given base size but scales with Dynamic Type
    /// relative to the specified text style. Hero/display sizes cap at
    /// `.accessibility1` to prevent layout breakage.
    private static func scaled(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design = .default,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .system(size: size, weight: weight, design: design)
            .leading(.tight)
    }

    // MARK: Semantic aliases (backwards compat)
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title.weight(.bold)
    static let headline = Font.headline
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption

    // MARK: Now screen tokens
    // Sizes/weights/tracking sourced from
    // docs/mockups/today-APPROVED-variant-a-2026-04-04.html

    /// Giant hero number (`.weight-num`, 84px/700, letter-spacing -2.5px).
    /// Use with `.tracking(-2.5)` at the call site.
    static let weightHero = scaled(size: 84, weight: .bold, relativeTo: .largeTitle)
    /// "lb"/"kg" suffix beside hero number (`.weight-num .unit`, 24px/500).
    static let weightUnit = scaled(size: 24, weight: .medium, relativeTo: .title)
    /// "Today" caption under hero number (`.today-label`, 13px/500).
    static let todayLabel = scaled(size: 13, weight: .medium, relativeTo: .footnote)
    /// 30D/90D/All segmented toggle (`.toggle .opt`, 12px/500).
    static let toggleOption = scaled(size: 12, weight: .medium, relativeTo: .caption)
    /// LOWEST/AVERAGE/HIGHEST uppercase caption (`.stat .label`,
    /// 9px/600, 0.5px tracking, uppercase). Use with `.tracking(0.5)`.
    static let statLabel = scaled(size: 9, weight: .semibold, relativeTo: .caption2)
    /// Stat card numeric value (`.stat .value`, 18px/700).
    static let statValue = scaled(size: 18, weight: .bold, relativeTo: .headline)
    /// Stat card unit suffix (`.stat .value .unit`, 10px/400).
    static let statUnit = scaled(size: 10, weight: .regular, relativeTo: .caption2)
    /// Primary "Weigh In" button (`.weigh-btn`, 16px/600, 0.3px tracking).
    /// Use with `.tracking(0.3)` at the call site.
    static let buttonLabel = scaled(size: 16, weight: .semibold, relativeTo: .callout)

    // MARK: WeighIn sheet tokens
    // Sizes/weights sourced from
    // docs/mockups/weighin-APPROVED-2026-04-04.html

    /// Stepper sheet hero number (`.weight-num`, 92px/700, -3px tracking).
    /// Slightly larger than `weightHero` to suit the sheet context.
    static let weighInHero = scaled(size: 92, weight: .bold, relativeTo: .largeTitle)
    /// "lb"/"kg" suffix beside weigh-in hero (`.weight-num .unit`, 26px/500).
    static let weighInHeroUnit = scaled(size: 26, weight: .medium, relativeTo: .title)
    /// Date pill chip label on sheet (`.sheet-date`, 13px/500).
    static let dateChip = scaled(size: 13, weight: .medium, relativeTo: .footnote)
    /// Delta preview text under hero (`.delta-preview`, 12px/400).
    static let deltaPreview = scaled(size: 12, weight: .regular, relativeTo: .caption)
    /// Add notes/photo chip label (`.add-chip`, 12px/500).
    static let addChip = scaled(size: 12, weight: .medium, relativeTo: .caption)
    /// Inline note field text (`.note-field`, 14px/400).
    static let noteField = scaled(size: 14, weight: .regular, relativeTo: .body)

    /// Delta display (retained for other screens).
    static let deltaDisplay = scaled(size: 17, weight: .medium, design: .rounded, relativeTo: .body)

    // MARK: Body tab tokens
    // Sizes/weights sourced from
    // docs/mockups/body-v1-2026-04-05.html (Variant B tiles)
    // docs/mockups/body-v4-refinements-2026-04-05.html (log measurement sheet)

    /// Section header title (`.sh-title`, 11px/700, 0.6px tracking, uppercase).
    /// Use with `.tracking(0.6)` at the call site.
    static let bodySectionTitle = scaled(size: 11, weight: .bold, relativeTo: .caption)
    /// Section header metadata (`.sh-meta`, 10px/500).
    static let bodySectionMeta = scaled(size: 10, weight: .medium, relativeTo: .caption2)
    /// Tile metric label (`.t-name`, 10px/600, 0.4px tracking, uppercase).
    /// Use with `.tracking(0.4)` at the call site.
    static let tileLabel = scaled(size: 10, weight: .semibold, relativeTo: .caption2)
    /// Tile value number (`.t-val`, 24px/700, -0.6px tracking).
    /// Use with `.tracking(-0.6)` at the call site.
    static let tileValue = scaled(size: 24, weight: .bold, relativeTo: .title2)
    /// Tile unit suffix (`.t-val .unit`, 11px/500).
    static let tileUnit = scaled(size: 11, weight: .medium, relativeTo: .caption)
    /// Tile delta indicator (`.t-delta`, 10px/600).
    static let tileDelta = scaled(size: 10, weight: .semibold, relativeTo: .caption2)
    /// Scan history card title (14px/700, -0.2px tracking).
    static let scanHistoryTitle = scaled(size: 14, weight: .bold, relativeTo: .subheadline)
    /// Scan history card metadata (11px/500).
    static let scanHistoryMeta = scaled(size: 11, weight: .medium, relativeTo: .caption)
    /// Log measurement sheet hero number (`.v-num`, 56px/700, -1.6px tracking).
    /// Use with `.tracking(-1.6)` at the call site.
    static let measurementHero = scaled(size: 56, weight: .bold, relativeTo: .largeTitle)
    /// Log measurement sheet unit suffix (`.v-num .unit`, 18px/500).
    static let measurementHeroUnit = scaled(size: 18, weight: .medium, relativeTo: .headline)
    /// Metric picker chip name (`.mname`, 14px/600).
    static let measurementPickerName = scaled(size: 14, weight: .semibold, relativeTo: .subheadline)

    // MARK: Trends screen tokens
    // Sizes/weights/tracking sourced from
    // docs/mockups/trends-APPROVED-2026-04-05.html

    /// Metric chip name label (`.metric-chip .metric-name`, 14px/600,
    /// -0.1px tracking). Use with `.tracking(-0.1)` at the call site.
    static let trendsMetricName = scaled(size: 14, weight: .semibold, relativeTo: .subheadline)
    /// Range tab option — M/6M/Y/All (`.range-tabs .opt`, 12px/500).
    static let trendsRangeTab = scaled(size: 12, weight: .medium, relativeTo: .caption)
    /// Single-hero delta number (`.single-hero .main-num`, 44px/700,
    /// -1.2px tracking). Use with `.tracking(-1.2)` at the call site.
    static let trendsHero = scaled(size: 44, weight: .bold, relativeTo: .largeTitle)
    /// Unit suffix beside hero delta (`.single-hero .main-num .unit`,
    /// 15px/500).
    static let trendsHeroUnit = scaled(size: 15, weight: .medium, relativeTo: .subheadline)
    /// Period sub-line beneath hero (`.hero-sub`, 11px/500).
    static let trendsHeroSub = scaled(size: 11, weight: .medium, relativeTo: .caption)
    /// Chart axis labels (`.chart-y-labels`, `.chart-x-labels`, 9px/500).
    static let trendsAxisLabel = scaled(size: 9, weight: .medium, relativeTo: .caption2)
    /// Chart legend label (`.legend-item`, 9.5px/500).
    static let trendsLegend = scaled(size: 9, weight: .medium, relativeTo: .caption2)
    /// Stats row uppercase caption (`.stat .label`, 9px/600, 0.5px tracking).
    /// Use with `.tracking(0.5)` at the call site.
    static let trendsStatLabel = scaled(size: 9, weight: .semibold, relativeTo: .caption2)
    /// Stats row numeric value (`.stat .value`, 15px/700).
    static let trendsStatValue = scaled(size: 15, weight: .bold, relativeTo: .subheadline)
    /// Stats row unit suffix (`.stat .value .unit`, 9px/400).
    static let trendsStatUnit = scaled(size: 9, weight: .regular, relativeTo: .caption2)
    /// Empty-state title (`.chart-empty-state .ei-title`, 13px/600,
    /// -0.1px tracking). Use with `.tracking(-0.1)` at the call site.
    static let trendsEmptyTitle = scaled(size: 13, weight: .semibold, relativeTo: .footnote)
    /// Empty-state body copy (`.chart-empty-state .ei-body`, 11px/500).
    static let trendsEmptyBody = scaled(size: 11, weight: .medium, relativeTo: .caption)

    // MARK: History screen tokens

    /// History row date ("Wed, Apr 3") — 15pt medium.
    static let historyDate = scaled(size: 15, weight: .medium, relativeTo: .subheadline)
    /// History row weight value — 16pt semibold.
    static let historyValue = scaled(size: 16, weight: .semibold, relativeTo: .callout)
    /// History row delta ("+0.2") — 13pt medium.
    static let historyDelta = scaled(size: 13, weight: .medium, relativeTo: .footnote)
    /// History row notes preview — 12pt regular.
    static let historyNotes = scaled(size: 12, weight: .regular, relativeTo: .caption)
    /// History empty-state message — 15pt regular.
    static let historyEmpty = scaled(size: 15, weight: .regular, relativeTo: .subheadline)

    /// Deprecated: superseded by `weightHero` (84pt) on the Now screen.
    /// Retained temporarily; remove once no longer referenced.
    @available(*, deprecated, message: "Use weightHero (84pt) — matches approved Now mockup.")
    static let weightDisplay = scaled(size: 64, weight: .bold, design: .rounded, relativeTo: .largeTitle)
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
