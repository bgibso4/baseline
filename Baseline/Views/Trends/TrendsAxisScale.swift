import Foundation

/// Pure dual-axis math for the Trends charts. Extracted from `TrendsView` so
/// the normalization and tick-value logic is testable without rendering
/// SwiftUI (see `TrendsAxisScaleTests`). Used by both the inline and
/// fullscreen charts when a secondary metric on a different scale is overlaid.
enum TrendsAxisScale {
    /// Normalize a value into the 0–1 range given a min/max. Returns 0.5 if the
    /// range is zero (degenerate single-value series).
    static func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max - min > 0 else { return 0.5 }
        return (value - min) / (max - min)
    }

    /// Compute `count` evenly-spaced real-value tick labels across a min/max
    /// range. Returns `[min]` for a zero-width range.
    static func axisTickValues(min: Double, max: Double, count: Int = 4) -> [Double] {
        guard max - min > 0 else { return [min] }
        return (0..<count).map { i in
            min + (max - min) * Double(i) / Double(count - 1)
        }
    }
}
