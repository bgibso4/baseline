import XCTest
import UIKit
@testable import Baseline

final class InBodyIntelligenceReaderTests: XCTestCase {

    private var page: UIImage!
    private var locator: FakeLocator!
    private var sections: FakeSectionReader!
    private var fallback: FakePageReader!

    override func setUpWithError() throws {
        page = try ScanFixtureTruth.image(named: "clean")
        locator = FakeLocator(rects: Dictionary(
            uniqueKeysWithValues: SheetSection.allCases.map { ($0, CGRect(x: 0, y: 0, width: 1, height: 0.1)) }
        ))
        sections = FakeSectionReader(readouts: [
            .bodyCompositionTotals: SectionReadout(values: ["weightKg": 199.4]),
            .obesity: SectionReadout(values: ["bodyFatPct": 6.1])
        ])
        var parsed = InBodyParseResult()
        parsed.bmi = 26.3
        fallback = FakePageReader(result: parsed)
    }

    private func makeReader() -> InBodyIntelligenceReader {
        InBodyIntelligenceReader(locator: locator, sections: sections, fallback: fallback)
    }

    func testAssemblesValuesFromSections() async {
        let result = await makeReader().read(page: page)

        XCTAssertEqual(result.weightKg, 199.4)
        XCTAssertEqual(result.bodyFatPct, 6.1)
        XCTAssertEqual(result.confidence["weightKg"], 0.9)
        XCTAssertTrue(result.isSelfValidated)
        XCTAssertEqual(fallback.readCount, 0)
    }

    func testCoreSectionsAreReadFirst() async {
        _ = await makeReader().read(page: page)

        // Sections overlap, so only the membership of the first five is fixed.
        XCTAssertEqual(
            Set(sections.order.prefix(5)),
            [.bodyCompositionValues, .bodyCompositionTotals, .muscleFat, .obesity, .basalMetabolicRate]
        )
        XCTAssertEqual(Set(sections.order), Set(SheetSection.allCases))
        XCTAssertEqual(sections.order.count, SheetSection.allCases.count)
    }

    func testReadsFourSectionsAtATime() async {
        _ = await makeReader().read(page: page)

        XCTAssertEqual(sections.mostAtOnce, 4)
    }

    func testOneSectionFailingLeavesOthers() async {
        sections.errors[.obesity] = FakeSectionReader.Failure.refused

        let result = await makeReader().read(page: page)

        XCTAssertNil(result.bodyFatPct)
        XCTAssertEqual(result.weightKg, 199.4)
        XCTAssertEqual(fallback.readCount, 0)
    }

    func testModelUnavailableFallsBack() async {
        sections.errors[.muscleFat] = SectionReadingError.modelUnavailable

        let result = await makeReader().read(page: page)

        XCTAssertEqual(result.bmi, 26.3)
        XCTAssertNil(result.weightKg)
        XCTAssertFalse(result.isSelfValidated)
        XCTAssertEqual(fallback.readCount, 1)
    }

    func testPageWithNothingReadableFallsBack() async {
        sections.readouts = [:]

        let result = await makeReader().read(page: page)

        XCTAssertEqual(result.bmi, 26.3)
        XCTAssertEqual(fallback.readCount, 1)
    }

    func testUnlocatablePageFallsBack() async {
        locator.rects = nil

        let result = await makeReader().read(page: page)

        XCTAssertEqual(result.bmi, 26.3)
        XCTAssertEqual(fallback.readCount, 1)
        XCTAssertTrue(sections.order.isEmpty)
    }

    func testUnpreparableImageFallsBack() async {
        let result = await makeReader().read(page: UIImage())

        XCTAssertEqual(result.bmi, 26.3)
        XCTAssertEqual(fallback.readCount, 1)
    }

    func testCropsMatchRects() async throws {
        locator.rects = [.obesity: CGRect(x: 0, y: 0.25, width: 0.5, height: 0.25)]

        _ = await makeReader().read(page: page)

        let crop = try XCTUnwrap(sections.crops[.obesity])
        let pixels = try XCTUnwrap(page.cgImage)
        XCTAssertEqual(Double(crop.width), Double(pixels.width) / 2, accuracy: 1)
        XCTAssertEqual(Double(crop.height), Double(pixels.height) / 4, accuracy: 1)
        XCTAssertEqual(sections.order, [.obesity], "sections without a rect are not asked about")
    }

    func testPrepareWarmsTheSectionReader() {
        makeReader().prepare()

        XCTAssertEqual(sections.prepareCount, 1)
    }
}

private final class FakeLocator: SectionLocating, @unchecked Sendable {
    var rects: [SheetSection: CGRect]?
    init(rects: [SheetSection: CGRect]?) { self.rects = rects }
    func sectionRects(in image: CGImage) async -> [SheetSection: CGRect]? { rects }
}

private final class FakeSectionReader: SectionReading, @unchecked Sendable {
    enum Failure: Error { case refused }

    var readouts: [SheetSection: SectionReadout]
    var errors: [SheetSection: Error] = [:]
    private(set) var prepareCount = 0
    private let lock = NSLock()
    private var startedOrder: [SheetSection] = []
    private var receivedCrops: [SheetSection: CGImage] = [:]
    private var inFlight = 0
    private var peak = 0

    var order: [SheetSection] { lock.withLock { startedOrder } }
    var crops: [SheetSection: CGImage] { lock.withLock { receivedCrops } }
    /// The most reads that were in progress at the same moment.
    var mostAtOnce: Int { lock.withLock { peak } }

    init(readouts: [SheetSection: SectionReadout]) { self.readouts = readouts }

    func read(_ section: SheetSection, crop: CGImage) async throws -> SectionReadout {
        lock.withLock {
            startedOrder.append(section)
            receivedCrops[section] = crop
            inFlight += 1
            peak = max(peak, inFlight)
        }
        defer { lock.withLock { inFlight -= 1 } }
        // Long enough for the reader to start every read it is going to overlap.
        try? await Task.sleep(for: .milliseconds(20))
        if let error = errors[section] { throw error }
        return readouts[section] ?? SectionReadout()
    }

    func prepare() { prepareCount += 1 }
}
