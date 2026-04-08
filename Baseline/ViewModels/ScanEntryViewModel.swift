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

    // MARK: - Editable Fields (all 35 InBody 570 metrics as Strings)
    // Stored as a dictionary to keep @Observable property count low and avoid
    // stack overflow in Swift's type metadata reflection.

    var fields: [String: String] = [:]
    var scanDate: Date?
    var retryCount: Int = 0
    var userEditedFields: Set<String> = []

    // Convenience accessors for the 7 required core fields + commonly used ones
    var weightKg: String {
        get { fields["weightKg", default: ""] }
        set { fields["weightKg"] = newValue }
    }
    var skeletalMuscleMassKg: String {
        get { fields["skeletalMuscleMassKg", default: ""] }
        set { fields["skeletalMuscleMassKg"] = newValue }
    }
    var bodyFatMassKg: String {
        get { fields["bodyFatMassKg", default: ""] }
        set { fields["bodyFatMassKg"] = newValue }
    }
    var bodyFatPct: String {
        get { fields["bodyFatPct", default: ""] }
        set { fields["bodyFatPct"] = newValue }
    }
    var totalBodyWaterL: String {
        get { fields["totalBodyWaterL", default: ""] }
        set { fields["totalBodyWaterL"] = newValue }
    }
    var bmi: String {
        get { fields["bmi", default: ""] }
        set { fields["bmi"] = newValue }
    }
    var basalMetabolicRate: String {
        get { fields["basalMetabolicRate", default: ""] }
        set { fields["basalMetabolicRate"] = newValue }
    }

    /// Get any field value by key.
    func fieldValue(_ key: String) -> String {
        fields[key, default: ""]
    }

    /// Set any field value by key.
    func setField(_ key: String, value: String) {
        fields[key] = value
    }

    /// Subscript for convenient field access by key.
    subscript(field key: String) -> String {
        get { fields[key, default: ""] }
        set { fields[key] = newValue }
    }

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

        let result = await InBodyDocumentParser.parse(image: image)

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
        let savedEdits = userEditedFields.reduce(into: [String: String]()) { dict, key in
            dict[key] = fields[key, default: ""]
        }
        current.merge(with: newResult, userEditedFields: userEditedFields)
        populateFields(from: current)
        // Restore user-edited values
        for (key, value) in savedEdits {
            fields[key] = value
        }
    }

    func populateFields(from result: InBodyParseResult) {
        parseResult = result

        func set(_ key: String, _ value: Double?, fmt: String = "auto") {
            if let v = value {
                switch fmt {
                case "3": fields[key] = String(format: "%.3f", v)
                case "0": fields[key] = String(format: "%.0f", v)
                default: fields[key] = formatValue(v)
                }
            } else {
                fields[key] = ""
            }
        }

        // Core
        set("weightKg", result.weightKg)
        set("skeletalMuscleMassKg", result.skeletalMuscleMassKg)
        set("bodyFatMassKg", result.bodyFatMassKg)
        set("bodyFatPct", result.bodyFatPct)
        set("totalBodyWaterL", result.totalBodyWaterL)
        set("bmi", result.bmi)
        set("basalMetabolicRate", result.basalMetabolicRate)

        // Body Composition
        set("intracellularWaterL", result.intracellularWaterL)
        set("extracellularWaterL", result.extracellularWaterL)
        set("dryLeanMassKg", result.dryLeanMassKg)
        set("leanBodyMassKg", result.leanBodyMassKg)
        set("inBodyScore", result.inBodyScore)

        // Segmental Lean
        set("rightArmLeanKg", result.rightArmLeanKg)
        set("leftArmLeanKg", result.leftArmLeanKg)
        set("trunkLeanKg", result.trunkLeanKg)
        set("rightLegLeanKg", result.rightLegLeanKg)
        set("leftLegLeanKg", result.leftLegLeanKg)

        // Segmental Fat
        set("rightArmFatKg", result.rightArmFatKg)
        set("leftArmFatKg", result.leftArmFatKg)
        set("trunkFatKg", result.trunkFatKg)
        set("rightLegFatKg", result.rightLegFatKg)
        set("leftLegFatKg", result.leftLegFatKg)

        // ECW/TBW, SMI, Visceral Fat
        set("ecwTbwRatio", result.ecwTbwRatio, fmt: "3")
        set("skeletalMuscleIndex", result.skeletalMuscleIndex)
        set("visceralFatLevel", result.visceralFatLevel, fmt: "0")

        // Segmental sufficiency %
        set("rightArmLeanPct", result.rightArmLeanPct)
        set("leftArmLeanPct", result.leftArmLeanPct)
        set("trunkLeanPct", result.trunkLeanPct)
        set("rightLegLeanPct", result.rightLegLeanPct)
        set("leftLegLeanPct", result.leftLegLeanPct)
        set("rightArmFatPct", result.rightArmFatPct)
        set("leftArmFatPct", result.leftArmFatPct)
        set("trunkFatPct", result.trunkFatPct)
        set("rightLegFatPct", result.rightLegFatPct)
        set("leftLegFatPct", result.leftLegFatPct)

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
        func f(_ key: String) -> Double? { Double(fields[key, default: ""]) }

        var missing: [String] = []
        let w = f("weightKg"); if w == nil { missing.append("Weight") }
        let smm = f("skeletalMuscleMassKg"); if smm == nil { missing.append("Skeletal Muscle Mass") }
        let bfm = f("bodyFatMassKg"); if bfm == nil { missing.append("Body Fat Mass") }
        let bf = f("bodyFatPct"); if bf == nil { missing.append("Body Fat %") }
        let tbw = f("totalBodyWaterL"); if tbw == nil { missing.append("Total Body Water") }
        let b = f("bmi"); if b == nil { missing.append("BMI") }
        let bmr = f("basalMetabolicRate"); if bmr == nil { missing.append("BMR") }

        guard missing.isEmpty,
              let w, let smm, let bfm, let bf, let tbw, let b, let bmr else {
            throw SaveError.missingRequiredFields(missing)
        }

        var payload = InBodyPayload(
            weightKg: w, skeletalMuscleMassKg: smm, bodyFatMassKg: bfm,
            bodyFatPct: bf, totalBodyWaterL: tbw, bmi: b, basalMetabolicRate: bmr
        )
        payload.intracellularWaterL = f("intracellularWaterL")
        payload.extracellularWaterL = f("extracellularWaterL")
        payload.dryLeanMassKg = f("dryLeanMassKg")
        payload.leanBodyMassKg = f("leanBodyMassKg")
        payload.inBodyScore = f("inBodyScore")
        payload.rightArmLeanKg = f("rightArmLeanKg")
        payload.leftArmLeanKg = f("leftArmLeanKg")
        payload.trunkLeanKg = f("trunkLeanKg")
        payload.rightLegLeanKg = f("rightLegLeanKg")
        payload.leftLegLeanKg = f("leftLegLeanKg")
        payload.rightArmFatKg = f("rightArmFatKg")
        payload.leftArmFatKg = f("leftArmFatKg")
        payload.trunkFatKg = f("trunkFatKg")
        payload.rightLegFatKg = f("rightLegFatKg")
        payload.leftLegFatKg = f("leftLegFatKg")
        payload.ecwTbwRatio = f("ecwTbwRatio")
        payload.skeletalMuscleIndex = f("skeletalMuscleIndex")
        payload.visceralFatLevel = f("visceralFatLevel")
        payload.rightArmLeanPct = f("rightArmLeanPct")
        payload.leftArmLeanPct = f("leftArmLeanPct")
        payload.trunkLeanPct = f("trunkLeanPct")
        payload.rightLegLeanPct = f("rightLegLeanPct")
        payload.leftLegLeanPct = f("leftLegLeanPct")
        payload.rightArmFatPct = f("rightArmFatPct")
        payload.leftArmFatPct = f("leftArmFatPct")
        payload.trunkFatPct = f("trunkFatPct")
        payload.rightLegFatPct = f("rightLegFatPct")
        payload.leftLegFatPct = f("leftLegFatPct")
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
