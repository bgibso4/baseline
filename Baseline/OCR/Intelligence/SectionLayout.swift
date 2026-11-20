import CoreGraphics

/// Works out where each section of the sheet is from the headings that were found.
///
/// The sheet's layout is fixed, so the headings found on a page give its
/// scale and offset; a heading that was missed (pen marks, misprints) is
/// predicted from the others. Pure geometry — no Vision, no images.
enum SectionLayout {

    /// - Parameter found: heading → distance of its centre from the top of the page, 0...1.
    /// - Returns: section → rectangle in normalised, top-left-origin page
    ///   coordinates, clamped to the page. Sections that fall off the page are
    ///   omitted. `nil` when fewer than two headings were found.
    static func rects(found: [SheetHeading: Double]) -> [SheetSection: CGRect]? {
        guard let fit = Fit(found) else { return nil }
        func position(_ heading: SheetHeading) -> Double {
            found[heading] ?? fit.predict(heading)
        }

        var rects: [SheetSection: CGRect] = [:]
        for band in bands {
            let top = position(band.from) + headingEdge
            let bottom = position(band.to) - headingEdge + band.extraBelow
            rects[band.section] = clamped(x: band.columns, top: top, bottom: bottom)
        }
        let firstHeading = position(.bodyComposition)
        rects[.header] = clamped(x: 0...1, top: firstHeading - headerHeight, bottom: firstHeading - headingEdge)
        return rects
    }

    // MARK: - Layout constants

    private struct Band {
        let section: SheetSection
        let from: SheetHeading
        let to: SheetHeading
        /// Horizontal extent, as a fraction of the page width.
        let columns: ClosedRange<Double>
        var extraBelow: Double = 0
    }

    private static let leftColumn = 0.0...0.66
    private static let rightColumn = 0.60...1.0
    /// Where the right column prints a lone value under its heading.
    private static let singleValue = 0.66...0.92

    /// Each section runs from its own heading down to the next one. The
    /// horizontal extent is as narrow as the section allows: the less
    /// unrelated print in a crop, the more reliably it is read.
    private static let bands: [Band] = [
        // One table, two questions: its values column and its totals.
        Band(section: .bodyCompositionValues, from: .bodyComposition, to: .muscleFat, columns: 0.0...0.31),
        Band(section: .bodyCompositionTotals, from: .bodyComposition, to: .muscleFat, columns: 0.29...0.66),
        Band(section: .muscleFat, from: .muscleFat, to: .obesity, columns: leftColumn),
        Band(section: .obesity, from: .obesity, to: .segmentalLean, columns: leftColumn),
        // Only the strip where the bars end and the results are printed.
        // Runs a little past the next heading: when that heading is missed its
        // predicted position can sit high enough to cut off the last row.
        Band(section: .segmentalLean, from: .segmentalLean, to: .ecwTbw, columns: 0.36...0.60, extraBelow: 0.02),
        // Misprinted sheets print the ratio level with the next heading.
        Band(section: .ecwTbw, from: .ecwTbw, to: .history, columns: leftColumn, extraBelow: 0.03),
        Band(section: .segmentalFat, from: .segmentalFat, to: .basalMetabolicRate, columns: rightColumn),
        // A single short number mid-column: a full-width strip is misread (2205 as 22005).
        Band(section: .basalMetabolicRate, from: .basalMetabolicRate, to: .visceralFat, columns: singleValue),
        // Stops before the Low / 10 / High scale printed beside the level.
        Band(section: .visceralFat, from: .visceralFat, to: .smi, columns: 0.60...0.77),
        Band(section: .smi, from: .smi, to: .resultsInterpretation, columns: singleValue)
    ]

    /// Half the height of a heading line: keeps the heading text out of the crop.
    private static let headingEdge = 0.008
    /// The ID / height / age / test-date strip above the first heading.
    private static let headerHeight = 0.075

    private static func clamped(x: ClosedRange<Double>, top: Double, bottom: Double) -> CGRect? {
        let clampedTop = max(top, 0), clampedBottom = min(bottom, 1)
        guard clampedBottom > clampedTop else { return nil }
        return CGRect(
            x: x.lowerBound,
            y: clampedTop,
            width: x.upperBound - x.lowerBound,
            height: clampedBottom - clampedTop
        )
    }

    // MARK: - Fit

    /// Least-squares line from reference positions to observed positions.
    private struct Fit {
        let slope: Double
        let offset: Double

        init?(_ found: [SheetHeading: Double]) {
            guard found.count >= 2 else { return nil }
            let count = Double(found.count)
            let sumX = found.keys.reduce(0) { $0 + $1.referenceY }
            let sumY = found.values.reduce(0, +)
            let sumXX = found.keys.reduce(0) { $0 + $1.referenceY * $1.referenceY }
            let sumXY = found.reduce(0) { $0 + $1.key.referenceY * $1.value }
            let spread = count * sumXX - sumX * sumX
            guard spread > 0 else { return nil }
            slope = (count * sumXY - sumX * sumY) / spread
            offset = (sumY - slope * sumX) / count
        }

        func predict(_ heading: SheetHeading) -> Double {
            slope * heading.referenceY + offset
        }
    }
}
