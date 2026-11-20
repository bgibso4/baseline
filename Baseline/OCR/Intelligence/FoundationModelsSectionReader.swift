import CoreGraphics
import Foundation
import FoundationModels

/// Reads a section crop with Apple's on-device language model.
///
/// On-device only: this uses `SystemLanguageModel.default` and nothing
/// else. Scan images must never be sent to a server-side model.
struct FoundationModelsSectionReader: SectionReading {

    private static let instructions = """
        You read InBody 570 body composition result sheets. Report the printed \
        result values for today's test exactly as printed. The bar charts have \
        axis tick numbers (like 10.0, 15.0, 20.0) that are NOT results; the \
        result is the number printed at the end of each bar. Ignore handwriting \
        and pen marks. If a value cannot be read, leave it empty. Never guess.
        """

    func prepare() {
        LanguageModelSession(instructions: Self.instructions).prewarm()
    }

    func read(_ section: SheetSection, crop: CGImage) async throws -> SectionReadout {
        var readout = SectionReadout()
        switch section {
        case .header:
            let question = "This is the sheet header with the Test Date / Time."
            let answer: SectionSchemas.Header = try await ask(crop, question)
            if let year = answer.year, let month = answer.month, let day = answer.day {
                readout.testDate = DateComponents(year: year, month: month, day: day)
            }
        case .bodyCompositionValues:
            let question = "This is the Values column of the Body Composition Analysis table: "
                + "four numbers, top to bottom."
            let answer: SectionSchemas.BodyCompositionValues = try await ask(crop, question)
            readout.values = Self.present([
                "intracellularWaterL": answer.intracellularWater,
                "extracellularWaterL": answer.extracellularWater,
                "dryLeanMassKg": answer.dryLeanMass,
                "bodyFatMassKg": answer.bodyFatMass
            ])
        case .bodyCompositionTotals:
            let question = "These are the three totals of the Body Composition Analysis table, left to right."
            let answer: SectionSchemas.BodyCompositionTotals = try await ask(crop, question)
            readout.values = Self.present([
                "totalBodyWaterL": answer.totalBodyWater,
                "leanBodyMassKg": answer.leanBodyMass,
                "weightKg": answer.weight
            ])
        case .muscleFat:
            let answer: SectionSchemas.MuscleFat = try await ask(crop, "This is the Muscle-Fat Analysis bar chart.")
            readout.values = Self.present(["skeletalMuscleMassKg": answer.skeletalMuscleMass])
            // Weight and fat mass are also in the table above: a second copy to compare.
            readout.repeated = Self.present(["weightKg": answer.weight, "bodyFatMassKg": answer.bodyFatMass])
        case .obesity:
            let answer: SectionSchemas.Obesity = try await ask(crop, "This is the Obesity Analysis bar chart.")
            readout.values = Self.present(["bmi": answer.bmi, "bodyFatPct": answer.percentBodyFat])
        case .segmentalLean:
            let question = "This is the right-hand end of the Segmental Lean Analysis bars, "
                + "where the results are printed."
            let answer: SectionSchemas.SegmentalLean = try await ask(crop, question)
            readout.values = SegmentalLeanPairing.fields(from: answer.numbers)
            if readout.values.isEmpty {
                Log.scan.info("Section reader: segmental lean list of \(answer.numbers.count) numbers rejected")
            }
        case .ecwTbw:
            let answer: SectionSchemas.EcwTbw = try await ask(crop, "This is the ECW/TBW Analysis bar chart.")
            readout.values = Self.present(["ecwTbwRatio": answer.ratio])
        case .segmentalFat:
            let question = "This is the Segmental Fat Analysis list. "
                + "Each of its five rows reads like: Right Arm ( 0.2lbs) 14.4%."
            let pounds: SectionSchemas.SegmentalFatPounds = try await ask(crop, question)
            let percents: SectionSchemas.SegmentalFatPercents = try await ask(crop, question)
            readout.values = SegmentalFatPairing.fields(lbs: pounds.numbers, percents: percents.numbers)
        case .basalMetabolicRate:
            let answer: SectionSchemas.BasalMetabolicRate = try await ask(crop, "This shows the Basal Metabolic Rate.")
            readout.values = Self.present(["basalMetabolicRate": answer.kcal.map(Double.init)])
        case .visceralFat:
            let answer: SectionSchemas.VisceralFat = try await ask(crop, "This shows the Visceral Fat Level.")
            readout.values = Self.present(["visceralFatLevel": answer.level.map(Double.init)])
        case .smi:
            let answer: SectionSchemas.SkeletalMuscleIndex = try await ask(crop, "This shows the SMI.")
            readout.values = Self.present(["skeletalMuscleIndex": answer.smi])
        }
        return readout
    }

    /// One fresh session per question, so no transcript builds up and each
    /// answer depends only on its own crop. Greedy sampling keeps reads repeatable.
    private func ask<Answer: Generable>(_ crop: CGImage, _ what: String) async throws -> Answer {
        guard SystemLanguageModel.default.availability == .available else {
            throw SectionReadingError.modelUnavailable
        }
        let session = LanguageModelSession(instructions: Self.instructions)
        do {
            return try await session.respond(
                generating: Answer.self,
                options: GenerationOptions(samplingMode: .greedy)
            ) {
                "\(what) Read the printed result values exactly as printed. Leave a value empty if you cannot read it."
                Attachment(crop)
            }.content
        } catch SystemLanguageModel.Error.assetsUnavailable {
            throw SectionReadingError.modelUnavailable
        } catch LanguageModelError.rateLimited(let limit) {
            // The system is refusing every request for now, so the model cannot read this page.
            let reset = limit.resetDate.map { "\($0)" } ?? "unknown"
            Log.scan.error("On-device model rate limited: \(limit.debugDescription); resets \(reset)")
            throw SectionReadingError.modelUnavailable
        }
    }

    private static func present(_ values: [String: Double?]) -> [String: Double] {
        values.compactMapValues { $0 }
    }
}
