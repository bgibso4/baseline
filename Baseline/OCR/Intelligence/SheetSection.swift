import Foundation

/// A region of the InBody 570 sheet that is read with one question.
enum SheetSection: CaseIterable {
    case header
    /// The table's Values column: intracellular water, extracellular water, dry lean mass, body fat mass.
    case bodyCompositionValues
    /// The table's three totals: total body water, lean body mass, weight.
    case bodyCompositionTotals
    case muscleFat, obesity, segmentalLean, ecwTbw
    case segmentalFat, basalMetabolicRate, visceralFat, smi
}
