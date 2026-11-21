import XCTest
@testable import Baseline

final class ScanPageReaderSelectorTests: XCTestCase {

    func testIntelligenceOnlyWhenAvailableAndSeesImages() {
        XCTAssertTrue(
            ScanPageReaderSelector.reader(modelIsAvailable: true, modelSeesImages: true) is InBodyIntelligenceReader
        )
        for (available, seesImages) in [(true, false), (false, true), (false, false)] {
            XCTAssertTrue(
                ScanPageReaderSelector.reader(modelIsAvailable: available, modelSeesImages: seesImages)
                    is ParserPageReader,
                "available=\(available) seesImages=\(seesImages)"
            )
        }
    }

    func testOnlyTheModelReaderIsTrustedWithOnePage() {
        XCTAssertTrue(ScanPageReaderSelector.reader(modelIsAvailable: true, modelSeesImages: true).needsOnlyOnePage)
        XCTAssertFalse(ScanPageReaderSelector.reader(modelIsAvailable: false, modelSeesImages: false).needsOnlyOnePage)
    }
}
