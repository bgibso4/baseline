import UIKit

/// Normalized bounding boxes for each section of the InBody 570 result sheet.
/// Coordinates are in 0–1 space (top-left origin, matching CGImage conventions).
enum InBody570RegionMap {

    struct Region {
        let id: String
        let rect: CGRect
        let label: String
    }

    static let header = Region(id: "R1", rect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.06), label: "Header")
    static let bodyComposition = Region(id: "R2", rect: CGRect(x: 0.0, y: 0.06, width: 0.55, height: 0.18), label: "Body Composition Analysis")
    static let muscleFat = Region(id: "R3", rect: CGRect(x: 0.0, y: 0.24, width: 0.55, height: 0.12), label: "Muscle-Fat Analysis")
    static let obesity = Region(id: "R4", rect: CGRect(x: 0.0, y: 0.36, width: 0.55, height: 0.06), label: "Obesity Analysis")
    static let segmentalLean = Region(id: "R5", rect: CGRect(x: 0.0, y: 0.42, width: 0.55, height: 0.16), label: "Segmental Lean Analysis")
    static let ecwTbw = Region(id: "R6", rect: CGRect(x: 0.0, y: 0.58, width: 0.55, height: 0.06), label: "ECW/TBW Analysis")
    static let segmentalFat = Region(id: "R7", rect: CGRect(x: 0.55, y: 0.06, width: 0.45, height: 0.16), label: "Segmental Fat Analysis")
    static let bmr = Region(id: "R8", rect: CGRect(x: 0.55, y: 0.22, width: 0.45, height: 0.06), label: "Basal Metabolic Rate")
    static let smi = Region(id: "R9", rect: CGRect(x: 0.55, y: 0.28, width: 0.45, height: 0.05), label: "SMI")
    static let visceralFat = Region(id: "R10", rect: CGRect(x: 0.55, y: 0.33, width: 0.45, height: 0.05), label: "Visceral Fat")

    static let allRegions: [Region] = [
        header, bodyComposition, muscleFat, obesity, segmentalLean,
        ecwTbw, segmentalFat, bmr, smi, visceralFat
    ]

    static func cropAll(from image: UIImage) -> [(Region, UIImage)] {
        allRegions.compactMap { region in
            guard let cropped = DocumentCorrector.cropRegion(image, normalizedRect: region.rect) else { return nil }
            return (region, cropped)
        }
    }
}
