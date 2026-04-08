import XCTest
import UIKit
@testable import Baseline

final class InBodyOCRParserTests: XCTestCase {

    func testProcessImage_ReturnsResult() async {
        let size = CGSize(width: 800, height: 1200)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let result = await InBodyOCRParser.processImage(testImage)
        XCTAssertNil(result.weightKg)
        XCTAssertNil(result.bmi)
    }

    func testMerge_HigherConfidenceWins() {
        var result1 = InBodyParseResult()
        result1.weightKg = 90.0
        result1.confidence["weightKg"] = 0.5

        var result2 = InBodyParseResult()
        result2.weightKg = 91.0
        result2.confidence["weightKg"] = 0.9

        result1.merge(with: result2, userEditedFields: [])
        XCTAssertEqual(result1.weightKg, 91.0)
        XCTAssertEqual(result1.confidence["weightKg"], 0.9)
    }

    func testMerge_UserEditedFieldsPreserved() {
        var result1 = InBodyParseResult()
        result1.weightKg = 90.0
        result1.confidence["weightKg"] = 0.5

        var result2 = InBodyParseResult()
        result2.weightKg = 91.0
        result2.confidence["weightKg"] = 0.9

        result1.merge(with: result2, userEditedFields: ["weightKg"])
        XCTAssertEqual(result1.weightKg, 90.0)
    }

    func testMerge_FillsMissingFields() {
        var result1 = InBodyParseResult()
        result1.weightKg = 90.0
        result1.confidence["weightKg"] = 0.8

        var result2 = InBodyParseResult()
        result2.bmi = 25.0
        result2.confidence["bmi"] = 0.7

        result1.merge(with: result2, userEditedFields: [])
        XCTAssertEqual(result1.weightKg, 90.0)
        XCTAssertEqual(result1.bmi, 25.0)
    }
}
