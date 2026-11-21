import XCTest
import UIKit
@testable import Baseline

final class ScanImagePreparerTests: XCTestCase {

    func testCleanFixtureBecomesEightBitSRGB() throws {
        let fixture = try ScanFixtureTruth.image(named: "clean")

        let prepared = try XCTUnwrap(ScanImagePreparer.standardRangeImage(from: fixture))

        XCTAssertEqual(prepared.bitsPerComponent, 8)
        XCTAssertEqual(prepared.colorSpace?.name, CGColorSpace.sRGB)
        XCTAssertEqual(prepared.width, Int(fixture.size.width * fixture.scale))
        XCTAssertEqual(prepared.height, Int(fixture.size.height * fixture.scale))
    }

    func testOrientationIsBakedIn() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let upright = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image { _ in }
        let rotated = UIImage(cgImage: try XCTUnwrap(upright.cgImage), scale: 1, orientation: .right)

        let prepared = try XCTUnwrap(ScanImagePreparer.standardRangeImage(from: rotated))

        XCTAssertEqual(prepared.width, 200)
        XCTAssertEqual(prepared.height, 100)
    }

    func testLargePageIsReducedToTheSizeTheModelWasMeasuredAt() throws {
        // A 3x screen-scale render, as the scan flow's downscale produces on a phone.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let page = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 2000), format: format).image { _ in }

        let prepared = try XCTUnwrap(ScanImagePreparer.standardRangeImage(from: page))

        XCTAssertEqual(prepared.height, 2400)
        XCTAssertEqual(prepared.width, 1200)
    }

    func testEmptyImageIsNil() {
        XCTAssertNil(ScanImagePreparer.standardRangeImage(from: UIImage()))
    }
}
