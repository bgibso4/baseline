import Foundation
import SwiftData
import UIKit

/// Drives the 5-screen scan entry flow state machine.
///
/// Steps: selectType -> selectMethod -> (camera -> review) OR manualEntry -> save.
/// In v1 only InBody 570 is supported, so selectType is pre-selected.
@Observable
class ScanEntryViewModel {

    enum Step: Equatable {
        case selectType
        case selectMethod
        case camera
        case review
        case manualEntry
    }

    enum SaveError: Error, LocalizedError {
        case missingRequiredFields([String])
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .missingRequiredFields(let fields):
                return "Missing required fields: \(fields.joined(separator: ", "))"
            case .encodingFailed:
                return "Failed to encode scan payload"
            }
        }
    }

    private let modelContext: ModelContext

    var currentStep: Step = .selectType
    var selectedType: ScanType = .inBody
    var selectedSource: ScanSource = .manual
    var parseResult: InBodyParseResult?
    var isProcessing = false
    var errorMessage: String?

    // MARK: - Editable Fields (all 22 InBody 570 metrics as Strings)

    // Core (7)
    var weightKg: String = ""
    var skeletalMuscleMassKg: String = ""
    var bodyFatMassKg: String = ""
    var bodyFatPct: String = ""
    var totalBodyWaterL: String = ""
    var bmi: String = ""
    var basalMetabolicRate: String = ""

    // Body Composition (5)
    var intracellularWaterL: String = ""
    var extracellularWaterL: String = ""
    var dryLeanMassKg: String = ""
    var leanBodyMassKg: String = ""
    var inBodyScore: String = ""

    // Segmental Lean (5)
    var rightArmLeanKg: String = ""
    var leftArmLeanKg: String = ""
    var trunkLeanKg: String = ""
    var rightLegLeanKg: String = ""
    var leftLegLeanKg: String = ""

    // Segmental Fat (5)
    var rightArmFatKg: String = ""
    var leftArmFatKg: String = ""
    var trunkFatKg: String = ""
    var rightLegFatKg: String = ""
    var leftLegFatKg: String = ""

    // MARK: - Low Confidence Tracking

    /// Field keys where OCR confidence was below threshold.
    var lowConfidenceFields: Set<String> = []

    /// Confidence threshold below which fields are flagged.
    private static let confidenceThreshold: Float = 0.7

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Navigation

    func selectType(_ type: ScanType) {
        selectedType = type
        currentStep = .selectMethod
    }

    func selectMethod(camera: Bool) {
        if camera {
            selectedSource = .ocr
            currentStep = .camera
        } else {
            selectedSource = .manual
            currentStep = .manualEntry
        }
    }

    func goBack() {
        switch currentStep {
        case .selectType:
            break // Can't go further back
        case .selectMethod:
            currentStep = .selectType
        case .camera:
            currentStep = .selectMethod
        case .review:
            currentStep = .selectMethod
        case .manualEntry:
            currentStep = .selectMethod
        }
    }

    // MARK: - OCR Processing

    func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        let result = await InBodyOCRParser.processImage(image)
        self.parseResult = result
        populateFields(from: result)

        isProcessing = false
        currentStep = .review
    }

    func populateFields(from result: InBodyParseResult) {
        parseResult = result

        // Core
        weightKg = result.weightKg.map { formatValue($0) } ?? ""
        skeletalMuscleMassKg = result.skeletalMuscleMassKg.map { formatValue($0) } ?? ""
        bodyFatMassKg = result.bodyFatMassKg.map { formatValue($0) } ?? ""
        bodyFatPct = result.bodyFatPct.map { formatValue($0) } ?? ""
        totalBodyWaterL = result.totalBodyWaterL.map { formatValue($0) } ?? ""
        bmi = result.bmi.map { formatValue($0) } ?? ""
        basalMetabolicRate = result.basalMetabolicRate.map { formatValue($0) } ?? ""

        // Body Composition
        intracellularWaterL = result.intracellularWaterL.map { formatValue($0) } ?? ""
        extracellularWaterL = result.extracellularWaterL.map { formatValue($0) } ?? ""
        dryLeanMassKg = result.dryLeanMassKg.map { formatValue($0) } ?? ""
        leanBodyMassKg = result.leanBodyMassKg.map { formatValue($0) } ?? ""
        inBodyScore = result.inBodyScore.map { formatValue($0) } ?? ""

        // Segmental Lean
        rightArmLeanKg = result.rightArmLeanKg.map { formatValue($0) } ?? ""
        leftArmLeanKg = result.leftArmLeanKg.map { formatValue($0) } ?? ""
        trunkLeanKg = result.trunkLeanKg.map { formatValue($0) } ?? ""
        rightLegLeanKg = result.rightLegLeanKg.map { formatValue($0) } ?? ""
        leftLegLeanKg = result.leftLegLeanKg.map { formatValue($0) } ?? ""

        // Segmental Fat
        rightArmFatKg = result.rightArmFatKg.map { formatValue($0) } ?? ""
        leftArmFatKg = result.leftArmFatKg.map { formatValue($0) } ?? ""
        trunkFatKg = result.trunkFatKg.map { formatValue($0) } ?? ""
        rightLegFatKg = result.rightLegFatKg.map { formatValue($0) } ?? ""
        leftLegFatKg = result.leftLegFatKg.map { formatValue($0) } ?? ""

        // Flag low-confidence fields
        lowConfidenceFields = []
        for (key, confidence) in result.confidence {
            if confidence < Self.confidenceThreshold {
                lowConfidenceFields.insert(key)
            }
        }
    }

    // MARK: - Save

    /// Whether the required 7 core fields are all non-empty.
    var canSave: Bool {
        !weightKg.isEmpty &&
        !skeletalMuscleMassKg.isEmpty &&
        !bodyFatMassKg.isEmpty &&
        !bodyFatPct.isEmpty &&
        !totalBodyWaterL.isEmpty &&
        !bmi.isEmpty &&
        !basalMetabolicRate.isEmpty
    }

    func save() throws {
        let payload = try buildPayload()
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: selectedType, source: selectedSource, payload: data)
        modelContext.insert(scan)
        try modelContext.save()
    }

    func buildPayload() throws -> InBodyPayload {
        var missing: [String] = []
        let w = Double(weightKg); if w == nil { missing.append("Weight") }
        let smm = Double(skeletalMuscleMassKg); if smm == nil { missing.append("Skeletal Muscle Mass") }
        let bfm = Double(bodyFatMassKg); if bfm == nil { missing.append("Body Fat Mass") }
        let bf = Double(bodyFatPct); if bf == nil { missing.append("Body Fat %") }
        let tbw = Double(totalBodyWaterL); if tbw == nil { missing.append("Total Body Water") }
        let b = Double(bmi); if b == nil { missing.append("BMI") }
        let bmr = Double(basalMetabolicRate); if bmr == nil { missing.append("BMR") }

        guard missing.isEmpty,
              let w, let smm, let bfm, let bf, let tbw, let b, let bmr else {
            throw SaveError.missingRequiredFields(missing)
        }

        return InBodyPayload(
            weightKg: w,
            skeletalMuscleMassKg: smm,
            bodyFatMassKg: bfm,
            bodyFatPct: bf,
            totalBodyWaterL: tbw,
            bmi: b,
            basalMetabolicRate: bmr,
            intracellularWaterL: Double(intracellularWaterL),
            extracellularWaterL: Double(extracellularWaterL),
            dryLeanMassKg: Double(dryLeanMassKg),
            leanBodyMassKg: Double(leanBodyMassKg),
            inBodyScore: Double(inBodyScore),
            rightArmLeanKg: Double(rightArmLeanKg),
            leftArmLeanKg: Double(leftArmLeanKg),
            trunkLeanKg: Double(trunkLeanKg),
            rightLegLeanKg: Double(rightLegLeanKg),
            leftLegLeanKg: Double(leftLegLeanKg),
            rightArmFatKg: Double(rightArmFatKg),
            leftArmFatKg: Double(leftArmFatKg),
            trunkFatKg: Double(trunkFatKg),
            rightLegFatKg: Double(rightLegFatKg),
            leftLegFatKg: Double(leftLegFatKg)
        )
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        // Show integer if whole, otherwise 1 decimal
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
