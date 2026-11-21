import UIKit
import XCTest
@testable import Baseline

/// Human-read ground truth for every scan fixture in `Fixtures/Scans`.
///
/// Mass values carry the sheet's native unit (lbs), as `InBodyParseResult`
/// stores them. Values were read off the images; the flat scans are of
/// Ben's own printouts and `review-sample` is the synthetic App Review sheet.
struct ScanFixtureTruth {
    let name: String
    let values: [String: Double]
    /// Year/month/day printed on the sheet; nil where it cannot be read.
    let testDate: DateComponents?
    /// The printer laid the data out of register with the form.
    let isMisprinted: Bool

    /// The 34 fields printed on an InBody 570 sheet, in the order the
    /// value lists below are written.
    static let keys: [String] = [
        "weightKg", "skeletalMuscleMassKg", "bodyFatMassKg", "bodyFatPct", "totalBodyWaterL", "bmi",
        "basalMetabolicRate",
        "intracellularWaterL", "extracellularWaterL", "dryLeanMassKg", "leanBodyMassKg",
        "rightArmLeanKg", "rightArmLeanPct", "leftArmLeanKg", "leftArmLeanPct", "trunkLeanKg", "trunkLeanPct",
        "rightLegLeanKg", "rightLegLeanPct", "leftLegLeanKg", "leftLegLeanPct",
        "ecwTbwRatio",
        "rightArmFatKg", "rightArmFatPct", "leftArmFatKg", "leftArmFatPct", "trunkFatKg", "trunkFatPct",
        "rightLegFatKg", "rightLegFatPct", "leftLegFatKg", "leftLegFatPct",
        "visceralFatLevel", "skeletalMuscleIndex"
    ]

    static let coreKeys = Array(keys.prefix(7))
    static let segmentalLeanKeys = Array(keys[11..<21])

    static let all: [ScanFixtureTruth] = [
        sheet("clean", sheet0414, date: (2026, 4, 14)),
        sheet("marked", sheet0319, date: (2026, 3, 19)),
        sheet("review-sample", reviewSample, date: (2026, 4, 10)),
        sheet("flat-0319", sheet0319, date: (2026, 3, 19)),
        sheet("flat-0414", sheet0414, date: (2026, 4, 14)),
        sheet("flat-0515-0723", sheet0515Early, date: (2026, 5, 15)),
        sheet("flat-0515-0726", sheet0515Late, date: (2026, 5, 15)),
        sheet("flat-0804", sheet0804, date: nil, misprinted: true),
        sheet("flat-0922", sheet0922, date: (2026, 9, 22))
    ]

    /// Loads a fixture from the test bundle with EXIF orientation baked in.
    static func image(named name: String) throws -> UIImage {
        let bundle = Bundle(for: ScanFixtureTruthTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "jpg"), "\(name).jpg not in test bundle")
        let image = try XCTUnwrap(UIImage(data: Data(contentsOf: url)), "\(name).jpg failed to decode")
        guard image.imageOrientation != .up else { return image }
        // Scale 1: the default is the screen's scale, which would enlarge the page threefold.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func sheet(
        _ name: String, _ values: [Double], date: (Int, Int, Int)?, misprinted: Bool = false
    ) -> ScanFixtureTruth {
        precondition(values.count == keys.count, "\(name): expected \(keys.count) values")
        return ScanFixtureTruth(
            name: name,
            values: Dictionary(uniqueKeysWithValues: zip(keys, values)),
            testDate: date.map { DateComponents(year: $0.0, month: $0.1, day: $0.2) },
            isMisprinted: misprinted
        )
    }

    // MARK: - Sheets

    private static let sheet0319: [Double] = [
        197.2, 105.8, 14.2, 7.2, 134.0, 26.0, 2162, 84.7, 49.4, 48.9, 183.0,
        11.49, 138.0, 11.38, 136.6, 80.9, 121.9, 27.67, 119.5, 28.02, 121.1, 0.369,
        0.2, 14.4, 0.2, 14.4, 6.8, 65.7, 2.2, 50.4, 2.2, 50.9, 1, 10.4
    ]
    private static let sheet0414: [Double] = [
        199.4, 108.2, 12.0, 6.1, 137.1, 26.3, 2205, 86.4, 50.7, 50.3, 187.4,
        11.51, 137.8, 11.40, 136.4, 80.9, 121.6, 28.55, 122.9, 28.59, 123.2, 0.369,
        0.2, 13.6, 0.2, 13.6, 5.7, 53.9, 1.8, 43.3, 1.8, 43.0, 1, 10.6
    ]
    private static let sheet0515Early: [Double] = [
        196.8, 108.5, 9.6, 4.9, 137.4, 26.0, 2205, 86.4, 50.9, 49.8, 187.2,
        11.79, 141.9, 11.57, 139.0, 82.1, 123.8, 28.55, 123.5, 28.66, 123.9, 0.370,
        0.2, 13.5, 0.2, 13.5, 4.0, 36.9, 1.5, 35.6, 1.5, 35.6, 1, 10.6
    ]
    private static let sheet0515Late: [Double] = [
        196.8, 108.0, 10.1, 5.1, 136.9, 26.0, 2200, 86.2, 50.7, 49.8, 186.7,
        11.73, 141.1, 11.49, 138.1, 81.7, 123.3, 28.62, 123.7, 28.75, 124.4, 0.370,
        0.2, 13.5, 0.2, 13.5, 4.2, 40.0, 1.5, 37.6, 1.5, 37.7, 1, 10.6
    ]
    private static let sheet0804: [Double] = [
        199.1, 108.9, 10.8, 5.5, 137.8, 26.3, 2214, 86.9, 50.9, 50.5, 188.3,
        11.55, 138.3, 11.64, 139.5, 81.7, 122.9, 28.59, 123.3, 29.10, 125.4, 0.369,
        0.2, 13.5, 0.2, 13.5, 4.9, 46.0, 1.8, 39.3, 1.8, 40.2, 1, 10.7
    ]
    private static let sheet0922: [Double] = [
        200.6, 109.4, 11.0, 5.5, 138.9, 26.5, 2227, 87.3, 51.6, 50.7, 189.6,
        11.79, 141.1, 11.79, 141.1, 82.7, 124.1, 28.84, 124.0, 29.04, 124.8, 0.372,
        0.2, 13.6, 0.2, 13.6, 4.9, 46.8, 1.8, 39.8, 1.8, 40.0, 1, 10.8
    ]
    private static let reviewSample: [Double] = [
        172.6, 78.4, 30.2, 17.5, 104.6, 24.8, 1765, 64.3, 40.3, 37.8, 142.4,
        8.42, 104.1, 8.31, 103.0, 61.2, 101.4, 21.06, 98.7, 20.94, 98.2, 0.385,
        1.9, 128.5, 1.9, 130.1, 14.6, 175.3, 4.4, 120.6, 4.4, 121.0, 5, 8.4
    ]
}
