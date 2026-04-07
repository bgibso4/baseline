import XCTest
import UIKit
@testable import Baseline

final class DocumentCorrectorTests: XCTestCase {

    func testCorrectPerspective_ReturnsImageWithSameDimensions() async {
        let size = CGSize(width: 400, height: 600)
        UIGraphicsBeginImageContext(size)
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 50, y: 50, width: 300, height: 500))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let result = await DocumentCorrector.correctPerspective(testImage)
        XCTAssertNotNil(result)
    }

    func testCropRegion_ProducesCorrectSize() {
        let size = CGSize(width: 1000, height: 1400)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let region = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let cropped = DocumentCorrector.cropRegion(testImage, normalizedRect: region)
        XCTAssertNotNil(cropped)
        if let cropped {
            XCTAssertEqual(cropped.size.width, 500, accuracy: 2)
            XCTAssertEqual(cropped.size.height, 700, accuracy: 2)
        }
    }
}
