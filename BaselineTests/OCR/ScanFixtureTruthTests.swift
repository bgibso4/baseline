import XCTest
@testable import Baseline

final class ScanFixtureTruthTests: XCTestCase {

    func testEveryFixtureLoadsAndIsComplete() throws {
        XCTAssertEqual(ScanFixtureTruth.all.count, 9)
        for truth in ScanFixtureTruth.all {
            let image = try ScanFixtureTruth.image(named: truth.name)
            XCTAssertGreaterThan(image.size.width, 0, truth.name)
            XCTAssertEqual(Set(truth.values.keys), Set(ScanFixtureTruth.keys), truth.name)
        }
    }

    func testKeysAreRealParseResultFields() {
        XCTAssertEqual(ScanFixtureTruth.keys.count, 34)
        XCTAssertTrue(Set(ScanFixtureTruth.keys).isSubset(of: Set(InBodyParseResult.allFieldKeys)))
    }
}
