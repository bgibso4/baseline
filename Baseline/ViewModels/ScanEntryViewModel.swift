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

    // New fields (13)
    var ecwTbwRatio: String = ""
    var skeletalMuscleIndex: String = ""
    var visceralFatLevel: String = ""
    var rightArmLeanPct: String = ""
    var leftArmLeanPct: String = ""
    var trunkLeanPct: String = ""
    var rightLegLeanPct: String = ""
    var leftLegLeanPct: String = ""
    var rightArmFatPct: String = ""
    var leftArmFatPct: String = ""
    var trunkFatPct: String = ""
    var rightLegFatPct: String = ""
    var leftLegFatPct: String = ""

    var scanDate: Date?
    var retryCount: Int = 0
    var userEditedFields: Set<String> = []

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

        if retryCount > 0 {
            mergeRetryResult(result)
        } else {
            self.parseResult = result
            populateFields(from: result)
        }

        isProcessing = false
        currentStep = .review
    }

    func markFieldEdited(_ fieldKey: String) {
        userEditedFields.insert(fieldKey)
    }

    func mergeRetryResult(_ newResult: InBodyParseResult) {
        guard var current = parseResult else {
            populateFields(from: newResult)
            return
        }
        // Snapshot user-edited string values before repopulating
        let savedEdits = captureUserEditedValues()
        current.merge(with: newResult, userEditedFields: userEditedFields)
        populateFields(from: current)
        // Restore user-edited values that populateFields would have overwritten
        restoreUserEditedValues(savedEdits)
    }

    private func captureUserEditedValues() -> [String: String] {
        var snapshot: [String: String] = [:]
        for key in userEditedFields {
            snapshot[key] = stringValue(for: key)
        }
        return snapshot
    }

    private func restoreUserEditedValues(_ snapshot: [String: String]) {
        for (key, value) in snapshot {
            setStringValue(value, for: key)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func stringValue(for key: String) -> String {
        switch key {
        case "weightKg": return weightKg
        case "skeletalMuscleMassKg": return skeletalMuscleMassKg
        case "bodyFatMassKg": return bodyFatMassKg
        case "bodyFatPct": return bodyFatPct
        case "totalBodyWaterL": return totalBodyWaterL
        case "bmi": return bmi
        case "basalMetabolicRate": return basalMetabolicRate
        case "intracellularWaterL": return intracellularWaterL
        case "extracellularWaterL": return extracellularWaterL
        case "dryLeanMassKg": return dryLeanMassKg
        case "leanBodyMassKg": return leanBodyMassKg
        case "inBodyScore": return inBodyScore
        case "rightArmLeanKg": return rightArmLeanKg
        case "leftArmLeanKg": return leftArmLeanKg
        case "trunkLeanKg": return trunkLeanKg
        case "rightLegLeanKg": return rightLegLeanKg
        case "leftLegLeanKg": return leftLegLeanKg
        case "rightArmFatKg": return rightArmFatKg
        case "leftArmFatKg": return leftArmFatKg
        case "trunkFatKg": return trunkFatKg
        case "rightLegFatKg": return rightLegFatKg
        case "leftLegFatKg": return leftLegFatKg
        case "ecwTbwRatio": return ecwTbwRatio
        case "skeletalMuscleIndex": return skeletalMuscleIndex
        case "visceralFatLevel": return visceralFatLevel
        case "rightArmLeanPct": return rightArmLeanPct
        case "leftArmLeanPct": return leftArmLeanPct
        case "trunkLeanPct": return trunkLeanPct
        case "rightLegLeanPct": return rightLegLeanPct
        case "leftLegLeanPct": return leftLegLeanPct
        case "rightArmFatPct": return rightArmFatPct
        case "leftArmFatPct": return leftArmFatPct
        case "trunkFatPct": return trunkFatPct
        case "rightLegFatPct": return rightLegFatPct
        case "leftLegFatPct": return leftLegFatPct
        default: return ""
        }
    }

    private func setStringValue(_ value: String, for key: String) {
        switch key {
        case "weightKg": weightKg = value
        case "skeletalMuscleMassKg": skeletalMuscleMassKg = value
        case "bodyFatMassKg": bodyFatMassKg = value
        case "bodyFatPct": bodyFatPct = value
        case "totalBodyWaterL": totalBodyWaterL = value
        case "bmi": bmi = value
        case "basalMetabolicRate": basalMetabolicRate = value
        case "intracellularWaterL": intracellularWaterL = value
        case "extracellularWaterL": extracellularWaterL = value
        case "dryLeanMassKg": dryLeanMassKg = value
        case "leanBodyMassKg": leanBodyMassKg = value
        case "inBodyScore": inBodyScore = value
        case "rightArmLeanKg": rightArmLeanKg = value
        case "leftArmLeanKg": leftArmLeanKg = value
        case "trunkLeanKg": trunkLeanKg = value
        case "rightLegLeanKg": rightLegLeanKg = value
        case "leftLegLeanKg": leftLegLeanKg = value
        case "rightArmFatKg": rightArmFatKg = value
        case "leftArmFatKg": leftArmFatKg = value
        case "trunkFatKg": trunkFatKg = value
        case "rightLegFatKg": rightLegFatKg = value
        case "leftLegFatKg": leftLegFatKg = value
        case "ecwTbwRatio": ecwTbwRatio = value
        case "skeletalMuscleIndex": skeletalMuscleIndex = value
        case "visceralFatLevel": visceralFatLevel = value
        case "rightArmLeanPct": rightArmLeanPct = value
        case "leftArmLeanPct": leftArmLeanPct = value
        case "trunkLeanPct": trunkLeanPct = value
        case "rightLegLeanPct": rightLegLeanPct = value
        case "leftLegLeanPct": leftLegLeanPct = value
        case "rightArmFatPct": rightArmFatPct = value
        case "leftArmFatPct": leftArmFatPct = value
        case "trunkFatPct": trunkFatPct = value
        case "rightLegFatPct": rightLegFatPct = value
        case "leftLegFatPct": leftLegFatPct = value
        default: break
        }
    }
    // swiftlint:enable cyclomatic_complexity

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

        // New fields (13)
        ecwTbwRatio = result.ecwTbwRatio.map { String(format: "%.3f", $0) } ?? ""
        skeletalMuscleIndex = result.skeletalMuscleIndex.map { formatValue($0) } ?? ""
        visceralFatLevel = result.visceralFatLevel.map { String(format: "%.0f", $0) } ?? ""
        rightArmLeanPct = result.rightArmLeanPct.map { formatValue($0) } ?? ""
        leftArmLeanPct = result.leftArmLeanPct.map { formatValue($0) } ?? ""
        trunkLeanPct = result.trunkLeanPct.map { formatValue($0) } ?? ""
        rightLegLeanPct = result.rightLegLeanPct.map { formatValue($0) } ?? ""
        leftLegLeanPct = result.leftLegLeanPct.map { formatValue($0) } ?? ""
        rightArmFatPct = result.rightArmFatPct.map { formatValue($0) } ?? ""
        leftArmFatPct = result.leftArmFatPct.map { formatValue($0) } ?? ""
        trunkFatPct = result.trunkFatPct.map { formatValue($0) } ?? ""
        rightLegFatPct = result.rightLegFatPct.map { formatValue($0) } ?? ""
        leftLegFatPct = result.leftLegFatPct.map { formatValue($0) } ?? ""
        scanDate = result.scanDate

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
        let scan = Scan(date: scanDate ?? Date(), type: selectedType, source: selectedSource, payload: data)
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

        var payload = InBodyPayload(
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
            leftLegFatKg: Double(leftLegFatKg),
            ecwTbwRatio: nil,
            skeletalMuscleIndex: nil,
            visceralFatLevel: nil,
            rightArmLeanPct: nil,
            leftArmLeanPct: nil,
            trunkLeanPct: nil,
            rightLegLeanPct: nil,
            leftLegLeanPct: nil,
            rightArmFatPct: nil,
            leftArmFatPct: nil,
            trunkFatPct: nil,
            rightLegFatPct: nil,
            leftLegFatPct: nil
        )
        payload.ecwTbwRatio = Double(ecwTbwRatio)
        payload.skeletalMuscleIndex = Double(skeletalMuscleIndex)
        payload.visceralFatLevel = Double(visceralFatLevel)
        payload.rightArmLeanPct = Double(rightArmLeanPct)
        payload.leftArmLeanPct = Double(leftArmLeanPct)
        payload.trunkLeanPct = Double(trunkLeanPct)
        payload.rightLegLeanPct = Double(rightLegLeanPct)
        payload.leftLegLeanPct = Double(leftLegLeanPct)
        payload.rightArmFatPct = Double(rightArmFatPct)
        payload.leftArmFatPct = Double(leftArmFatPct)
        payload.trunkFatPct = Double(trunkFatPct)
        payload.rightLegFatPct = Double(rightLegFatPct)
        payload.leftLegFatPct = Double(leftLegFatPct)
        return payload
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
