import Foundation

/// A printed section heading on the InBody 570 sheet, used as a vertical anchor.
enum SheetHeading: CaseIterable {
    // Left column, top to bottom.
    case bodyComposition, muscleFat, obesity, segmentalLean, ecwTbw, history
    // Right column, top to bottom.
    case segmentalFat, basalMetabolicRate, visceralFat, smi, resultsInterpretation

    var isRightColumn: Bool {
        switch self {
        case .bodyComposition, .muscleFat, .obesity, .segmentalLean, .ecwTbw, .history: false
        case .segmentalFat, .basalMetabolicRate, .visceralFat, .smi, .resultsInterpretation: true
        }
    }

    /// Where the heading sits on a reference sheet, in arbitrary units from
    /// the top. Only the spacing between headings matters: `SectionLayout`
    /// fits scale and offset to whatever headings were actually found.
    var referenceY: Double {
        switch self {
        case .bodyComposition: 320
        case .muscleFat: 610
        case .obesity: 872
        case .segmentalLean: 1055
        case .ecwTbw: 1457
        case .history: 1610
        case .segmentalFat: 515
        case .basalMetabolicRate: 740
        case .visceralFat: 805
        case .smi: 898
        case .resultsInterpretation: 962
        }
    }

    /// Whether recognised text (already lowercased and trimmed) is this heading.
    /// Includes the misreadings Vision produces on real printouts.
    func matches(_ text: String) -> Bool {
        switch self {
        case .bodyComposition: text.hasPrefix("body composition analysis")
        case .muscleFat: text.hasPrefix("muscle-fat analysis") || text.hasPrefix("muscle- fat analysis")
        case .obesity: text.hasPrefix("obesity analysis") || text.hasPrefix("obesity anaiysis")
        case .segmentalLean: text.hasPrefix("segmental lean")
        case .ecwTbw: text.hasPrefix("ecw/tbw analysis")
        case .history: text.hasPrefix("body composition history")
        case .segmentalFat: text.hasPrefix("segmental fat analysis")
        case .basalMetabolicRate: text.hasPrefix("basal metabolic rate")
        case .visceralFat: text.hasPrefix("visceral fat level")
        // Exact: the right column's explanatory text also starts with "SMI".
        case .smi: text == "smi"
        case .resultsInterpretation: text.hasPrefix("results interpretation")
        }
    }
}
