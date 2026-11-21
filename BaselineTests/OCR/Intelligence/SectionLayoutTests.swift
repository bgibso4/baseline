import XCTest
@testable import Baseline

final class SectionLayoutTests: XCTestCase {

    /// Every heading exactly where the reference sheet has it, on a page 2000 units tall.
    private func referencePositions(
        scale: Double = 1, offset: Double = 0, without missing: Set<SheetHeading> = []
    ) -> [SheetHeading: Double] {
        var found: [SheetHeading: Double] = [:]
        for heading in SheetHeading.allCases where !missing.contains(heading) {
            found[heading] = offset + scale * heading.referenceY / 2000
        }
        return found
    }

    func testAllHeadingsFoundGivesEverySection() throws {
        let rects = try XCTUnwrap(SectionLayout.rects(found: referencePositions()))

        XCTAssertEqual(Set(rects.keys), Set(SheetSection.allCases))
        let obesity = try XCTUnwrap(rects[.obesity])
        XCTAssertEqual(obesity.minY, 0.444, accuracy: 0.001)
        XCTAssertEqual(obesity.maxY, 0.5195, accuracy: 0.001)
        XCTAssertEqual(obesity.minX, 0, accuracy: 0.0001)
        XCTAssertEqual(obesity.maxX, 0.66, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(rects[.basalMetabolicRate]).minX, 0.66, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(rects[.smi]).maxX, 0.92, accuracy: 0.0001)
    }

    func testUpsideDownPageIsNotASheet() {
        let upsideDown = referencePositions().mapValues { 1 - $0 }

        XCTAssertNil(SectionLayout.rects(found: upsideDown))
    }

    func testBodyCompositionTableIsSplitIntoValuesAndTotals() throws {
        let rects = try XCTUnwrap(SectionLayout.rects(found: referencePositions()))

        // Same band, different columns: one question each, so the model
        // cannot answer a "value" with a "total".
        let values = try XCTUnwrap(rects[.bodyCompositionValues])
        let totals = try XCTUnwrap(rects[.bodyCompositionTotals])
        XCTAssertEqual(values.minY, totals.minY, accuracy: 0.0001)
        XCTAssertEqual(values.maxY, totals.maxY, accuracy: 0.0001)
        XCTAssertEqual(values.maxX, 0.31, accuracy: 0.0001)
        XCTAssertEqual(totals.minX, 0.29, accuracy: 0.0001)
        XCTAssertEqual(totals.maxX, 0.66, accuracy: 0.0001)
    }

    func testNarrowSectionsExcludeNeighbouringPrint() throws {
        let rects = try XCTUnwrap(SectionLayout.rects(found: referencePositions()))

        // Visceral fat: stop before the Low / 10 / High scale beside the level.
        XCTAssertEqual(try XCTUnwrap(rects[.visceralFat]).maxX, 0.77, accuracy: 0.0001)
        // Segmental lean: only the strip where the bars end and the results are printed.
        let lean = try XCTUnwrap(rects[.segmentalLean])
        XCTAssertEqual(lean.minX, 0.36, accuracy: 0.0001)
        XCTAssertEqual(lean.maxX, 0.60, accuracy: 0.0001)
    }

    func testMissingHeadingIsPredicted() throws {
        let rects = try XCTUnwrap(SectionLayout.rects(found: referencePositions(without: [.ecwTbw])))

        // Runs 0.02 past the predicted ECW/TBW heading so the last row is not cut off.
        XCTAssertEqual(try XCTUnwrap(rects[.segmentalLean]).maxY, 0.7405, accuracy: 0.001)
    }

    func testScaledAndShiftedSheet() throws {
        let found = referencePositions(scale: 0.8, offset: 0.1, without: [.obesity])
        let rects = try XCTUnwrap(SectionLayout.rects(found: found))

        XCTAssertEqual(try XCTUnwrap(rects[.muscleFat]).maxY, 0.1 + 0.8 * 0.436 - 0.008, accuracy: 0.001)
    }

    func testFewerThanTwoHeadingsIsNil() {
        XCTAssertNil(SectionLayout.rects(found: [:]))
        XCTAssertNil(SectionLayout.rects(found: [.obesity: 0.436]))
    }

    func testRectsAreClampedAndEmptyOnesDropped() throws {
        let rects = try XCTUnwrap(SectionLayout.rects(found: referencePositions(offset: 0.9)))

        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        for (section, rect) in rects {
            XCTAssertTrue(unit.contains(rect), "\(section) leaves the page: \(rect)")
            XCTAssertGreaterThan(rect.height, 0, "\(section)")
        }
        XCTAssertNil(rects[.ecwTbw], "a section wholly below the page is dropped")
        XCTAssertNotNil(rects[.header], "the header band still fits")
    }

    func testEcwTbwBandReachesBelowTheHistoryHeading() throws {
        let rects = try XCTUnwrap(SectionLayout.rects(found: referencePositions()))

        // Misprinted sheets print the ratio level with the next heading.
        XCTAssertEqual(try XCTUnwrap(rects[.ecwTbw]).maxY, 0.805 - 0.008 + 0.03, accuracy: 0.001)
    }

    func testHeadingMatching() {
        XCTAssertTrue(SheetHeading.obesity.matches("obesity anaiysis"))
        XCTAssertTrue(SheetHeading.muscleFat.matches("muscle- fat analysis"))
        XCTAssertTrue(SheetHeading.segmentalLean.matches("segmental lean body analysis"))
        XCTAssertTrue(SheetHeading.smi.matches("smi"))
        XCTAssertFalse(SheetHeading.smi.matches("smi skeletal muscle index(smi) is calculated"))
        XCTAssertFalse(SheetHeading.obesity.matches("body composition analysis"))
    }
}
