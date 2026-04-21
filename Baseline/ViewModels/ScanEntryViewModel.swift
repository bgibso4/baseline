import Foundation
import SwiftData
import UIKit
import VisionKit

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

    /// When non-nil, `save()` updates this scan in place instead of inserting a new one.
    /// Set by `loadForEdit` so the same VM drives the manual form for both new and edit flows.
    var editingScan: Scan?

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

    /// Confidence threshold — fields below this are flagged for review.
    /// Values at or above this pass; below it get flagged.
    /// Body comp grid (0.85), bullet-detected (0.9), segmental pairs (0.8) pass.
    /// Height-sorted ambiguous (0.7) *also* pass — these are frequently the
    /// correct bar-chart value. Cross-field math (see `CrossFieldValidator`)
    /// is responsible for catching wrong-but-confident values.
    /// Garbled (0.5) and no-confidence (0.0) still get flagged.
    private static let confidenceThreshold: Float = 0.70

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Edit Mode

    /// Seed the VM from an existing scan so the manual form renders the same
    /// layout for edit as for entry. Mass fields are converted from stored kg
    /// to the user's preferred display unit; `buildPayload()` converts back
    /// to kg on save.
    func loadForEdit(scan: Scan, payload: InBodyPayload, massPref: String) {
        self.editingScan = scan
        // Fall back to current defaults if the stored raw-string can't parse —
        // matches the production behavior (empty-string fallbacks default to
        // .inBody / .manual). In practice a saved Scan always has a valid pair.
        self.selectedType = scan.scanType ?? .inBody
        self.selectedSource = scan.scanSource ?? .manual
        self.scanDate = scan.date
        self.currentStep = .manualEntry

        let m: (Double) -> String = { kg in
            Self.formatLoaded(massPref == "kg" ? kg : UnitConversion.kgToLb(kg))
        }
        let om: (Double?) -> String = { kg in
            guard let kg else { return "" }
            return Self.formatLoaded(massPref == "kg" ? kg : UnitConversion.kgToLb(kg))
        }
        let f: (Double) -> String = { Self.formatLoaded($0) }
        let of: (Double?) -> String = { v in
            guard let v else { return "" }
            return Self.formatLoaded(v)
        }
        let ratio: (Double?) -> String = { v in
            guard let v else { return "" }
            return String(format: "%.3f", v)
        }
        let integer: (Double?) -> String = { v in
            guard let v else { return "" }
            return String(format: "%.0f", v)
        }

        // Core (required)
        fields["weightKg"] = m(payload.weightKg)
        fields["skeletalMuscleMassKg"] = m(payload.skeletalMuscleMassKg)
        fields["bodyFatMassKg"] = m(payload.bodyFatMassKg)
        fields["bodyFatPct"] = f(payload.bodyFatPct)
        fields["totalBodyWaterL"] = f(payload.totalBodyWaterL)
        fields["bmi"] = f(payload.bmi)
        fields["basalMetabolicRate"] = f(payload.basalMetabolicRate)

        // Body Composition (optional)
        fields["intracellularWaterL"] = of(payload.intracellularWaterL)
        fields["extracellularWaterL"] = of(payload.extracellularWaterL)
        fields["dryLeanMassKg"] = om(payload.dryLeanMassKg)
        fields["leanBodyMassKg"] = om(payload.leanBodyMassKg)
        fields["inBodyScore"] = of(payload.inBodyScore)

        // ECW/TBW + indices
        fields["ecwTbwRatio"] = ratio(payload.ecwTbwRatio)
        fields["skeletalMuscleIndex"] = of(payload.skeletalMuscleIndex)
        fields["visceralFatLevel"] = integer(payload.visceralFatLevel)

        // Segmental Lean (mass)
        fields["rightArmLeanKg"] = om(payload.rightArmLeanKg)
        fields["leftArmLeanKg"] = om(payload.leftArmLeanKg)
        fields["trunkLeanKg"] = om(payload.trunkLeanKg)
        fields["rightLegLeanKg"] = om(payload.rightLegLeanKg)
        fields["leftLegLeanKg"] = om(payload.leftLegLeanKg)

        // Segmental Lean (pct)
        fields["rightArmLeanPct"] = of(payload.rightArmLeanPct)
        fields["leftArmLeanPct"] = of(payload.leftArmLeanPct)
        fields["trunkLeanPct"] = of(payload.trunkLeanPct)
        fields["rightLegLeanPct"] = of(payload.rightLegLeanPct)
        fields["leftLegLeanPct"] = of(payload.leftLegLeanPct)

        // Segmental Fat (mass)
        fields["rightArmFatKg"] = om(payload.rightArmFatKg)
        fields["leftArmFatKg"] = om(payload.leftArmFatKg)
        fields["trunkFatKg"] = om(payload.trunkFatKg)
        fields["rightLegFatKg"] = om(payload.rightLegFatKg)
        fields["leftLegFatKg"] = om(payload.leftLegFatKg)

        // Segmental Fat (pct)
        fields["rightArmFatPct"] = of(payload.rightArmFatPct)
        fields["leftArmFatPct"] = of(payload.leftArmFatPct)
        fields["trunkFatPct"] = of(payload.trunkFatPct)
        fields["rightLegFatPct"] = of(payload.rightLegFatPct)
        fields["leftLegFatPct"] = of(payload.leftLegFatPct)
    }

    /// Formats a loaded numeric field for display.
    /// Integer if whole, one decimal otherwise.
    private static func formatLoaded(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
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

    /// All per-page parse results collected across scans (for consensus voting).
    var allPageResults: [InBodyParseResult] = []

    func processScan(_ scan: VNDocumentCameraScan) async {
        isProcessing = true
        errorMessage = nil

        let pageCount = scan.pageCount
        Log.scan.info("Processing \(pageCount) page(s), scan attempt \(retryCount + 1)")

        // Process pages one at a time to limit memory.
        // Downscale each page before parsing — the document camera captures
        // at full sensor resolution (~4000px) which is way more than OCR needs.
        for i in 0..<pageCount {
            Log.scan.debug("Parsing page \(i + 1)/\(pageCount)")
            let scaled = Self.downscale(scan.imageOfPage(at: i), maxDimension: 2048)
            let pageResult = await InBodyDocumentParser.parse(image: scaled)
            allPageResults.append(pageResult)
        }

        // Consensus vote across all collected pages/scans
        let voted = InBodyParseResult.consensusVote(allPageResults, userEditedFields: userEditedFields)

        if retryCount > 0 {
            // Preserve user-edited field values
            let savedEdits = userEditedFields.reduce(into: [String: String]()) { dict, key in
                dict[key] = fields[key, default: ""]
            }
            populateFields(from: voted)
            for (key, value) in savedEdits {
                fields[key] = value
            }
        } else {
            populateFields(from: voted)
        }

        Log.scan.info("Consensus vote from \(allPageResults.count) page(s): \(voted.confidence.filter { $0.value >= 0.85 }.count) high-confidence fields")

        isProcessing = false
        currentStep = .review
    }

    /// Downscales an image so its longest side is at most maxDimension.
    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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

        // Flag low-confidence fields: anything below threshold OR with no confidence data.
        // Fields with high confidence (≥0.8) from bullet detection or grid extraction are trusted.
        // Fields with no confidence entry at all are uncertain = flag them.
        lowConfidenceFields = []
        let allFieldKeys = [
            "weightKg", "skeletalMuscleMassKg", "bodyFatMassKg", "bodyFatPct",
            "totalBodyWaterL", "bmi", "basalMetabolicRate",
            "intracellularWaterL", "extracellularWaterL", "dryLeanMassKg", "leanBodyMassKg",
            "inBodyScore", "ecwTbwRatio", "skeletalMuscleIndex", "visceralFatLevel",
            "rightArmLeanKg", "leftArmLeanKg", "trunkLeanKg", "rightLegLeanKg", "leftLegLeanKg",
            "rightArmLeanPct", "leftArmLeanPct", "trunkLeanPct", "rightLegLeanPct", "leftLegLeanPct",
            "rightArmFatKg", "leftArmFatKg", "trunkFatKg", "rightLegFatKg", "leftLegFatKg",
            "rightArmFatPct", "leftArmFatPct", "trunkFatPct", "rightLegFatPct", "leftLegFatPct",
        ]
        // Sane value ranges — any value outside these is almost certainly wrong
        let saneRanges: [String: ClosedRange<Double>] = [
            "weightKg": 50...600, "skeletalMuscleMassKg": 30...300,
            "bodyFatMassKg": 1...200, "bodyFatPct": 1...70,
            "totalBodyWaterL": 20...300, "bmi": 10...60,
            "basalMetabolicRate": 800...4000,
            "intracellularWaterL": 10...200, "extracellularWaterL": 10...200,
            "dryLeanMassKg": 10...150, "leanBodyMassKg": 30...400,
            "ecwTbwRatio": 0.30...0.50, "skeletalMuscleIndex": 3...20,
            "visceralFatLevel": 1...30,
            "rightArmLeanKg": 2...30, "leftArmLeanKg": 2...30,
            "trunkLeanKg": 20...150, "rightLegLeanKg": 5...60, "leftLegLeanKg": 5...60,
            "rightArmLeanPct": 50...250, "leftArmLeanPct": 50...250,
            "trunkLeanPct": 50...250, "rightLegLeanPct": 50...250, "leftLegLeanPct": 50...250,
            "rightArmFatKg": 0.1...20, "leftArmFatKg": 0.1...20,
            "trunkFatKg": 1...50, "rightLegFatKg": 0.5...30, "leftLegFatKg": 0.5...30,
            "rightArmFatPct": 5...500, "leftArmFatPct": 5...500,
            "trunkFatPct": 20...500, "rightLegFatPct": 20...500, "leftLegFatPct": 20...500,
        ]

        for key in allFieldKeys {
            let valueStr = fields[key, default: ""]
            guard !valueStr.isEmpty else { continue }
            let conf = result.confidence[key] ?? 0

            // Flag if low confidence
            if conf < Self.confidenceThreshold {
                lowConfidenceFields.insert(key)
            }

            // Flag if value is outside sane range (regardless of confidence)
            if let value = Double(valueStr), let range = saneRanges[key] {
                if !range.contains(value) {
                    lowConfidenceFields.insert(key)
                }
            }
        }

        // Flag anything that fails a cross-field physical-identity check.
        // Catches most wrong-but-confident parser outputs — e.g. PBF read
        // off the wrong tick mark still has "high" confidence but doesn't
        // match BFM/weight*100.
        lowConfidenceFields.formUnion(CrossFieldValidator.validate(fields))
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

    /// Check if a scan already exists for the selected date.
    /// In edit mode, excludes the scan being edited so it never flags itself.
    func existingScanForSelectedDate() -> Scan? {
        let targetDate = Calendar.current.startOfDay(for: scanDate ?? Date())
        // SwiftData's #Predicate macro rejects Optional<UUID> vs UUID comparisons,
        // so branch explicitly rather than embed the optional in the predicate.
        let descriptor: FetchDescriptor<Scan>
        if let editingId = editingScan?.id {
            descriptor = FetchDescriptor<Scan>(
                predicate: #Predicate { scan in
                    scan.date == targetDate && scan.id != editingId
                }
            )
        } else {
            descriptor = FetchDescriptor<Scan>(
                predicate: #Predicate { scan in
                    scan.date == targetDate
                }
            )
        }
        return try? modelContext.fetch(descriptor).first
    }

    func save() throws {
        let payload = try buildPayload()
        let data = try JSONEncoder().encode(payload)
        let targetDate = Calendar.current.startOfDay(for: scanDate ?? Date())

        // Delete any OTHER scan already on the target date — excludes self in
        // edit mode. Capture its id first so its HK samples get cleaned up.
        var conflictID: UUID?
        if let conflict = existingScanForSelectedDate() {
            conflictID = conflict.id
            modelContext.delete(conflict)
        }

        let savedScan: Scan
        if let editing = editingScan {
            editing.payloadData = data
            editing.date = targetDate
            editing.type = selectedType.rawValue
            editing.source = selectedSource.rawValue
            editing.updatedAt = Date()
            savedScan = editing
        } else {
            let scan = Scan(date: targetDate, type: selectedType, source: selectedSource, payload: data)
            modelContext.insert(scan)
            savedScan = scan
        }
        try modelContext.save()

        // Mirror scan metrics to HealthKit. On edit (including date change) or
        // overwrite, wipe any prior samples tied to either the replaced scan
        // or the scan being saved, then write fresh samples tagged with the
        // saved scan's id so future edits can locate and replace them.
        // Extract primitives before the Task so no SwiftData managed object
        // crosses actor boundaries.
        let scanID = savedScan.id
        let scanDateForHK = savedScan.date
        let hkPayload = payload
        Task {
            if let conflictID { await HealthKitManager.mirror.deleteSamples(forSourceID: conflictID) }
            await HealthKitManager.mirror.deleteSamples(forSourceID: scanID)
            await HealthKitManager.mirror.saveScanMetrics(
                payload: hkPayload,
                date: scanDateForHK,
                sourceID: scanID
            )
        }

        // Auto-complete any matching goals. Mass fields are converted from
        // stored kg back to the user's preferred display unit to match how
        // goal target/start values were entered and stored.
        GoalAutoCompleter.checkCompletions(
            values: Self.trendMetricValues(from: payload),
            in: modelContext
        )
    }

    /// Maps an `InBodyPayload` into a dict keyed by `TrendMetric.rawValue`
    /// with values already converted to the user's display units.
    private static func trendMetricValues(from payload: InBodyPayload) -> [String: Double] {
        let massPref = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        let toMass: (Double) -> Double = { kg in
            massPref == "kg" ? kg : UnitConversion.kgToLb(kg)
        }

        var values: [String: Double] = [:]
        values[TrendMetric.weight.rawValue] = toMass(payload.weightKg)
        values[TrendMetric.bodyFatPct.rawValue] = payload.bodyFatPct
        values[TrendMetric.skeletalMuscle.rawValue] = toMass(payload.skeletalMuscleMassKg)
        values[TrendMetric.bmi.rawValue] = payload.bmi
        values[TrendMetric.fatMass.rawValue] = toMass(payload.bodyFatMassKg)
        values[TrendMetric.totalBodyWater.rawValue] = payload.totalBodyWaterL
        values[TrendMetric.bmr.rawValue] = payload.basalMetabolicRate

        if let lbm = payload.leanBodyMassKg { values[TrendMetric.leanBodyMass.rawValue] = toMass(lbm) }
        if let icw = payload.intracellularWaterL { values[TrendMetric.icw.rawValue] = icw }
        if let ecw = payload.extracellularWaterL { values[TrendMetric.ecw.rawValue] = ecw }
        if let dlm = payload.dryLeanMassKg { values[TrendMetric.dryLeanMass.rawValue] = toMass(dlm) }
        if let score = payload.inBodyScore { values[TrendMetric.inBodyScore.rawValue] = score }

        if let v = payload.rightArmLeanKg { values[TrendMetric.rightArmLean.rawValue] = toMass(v) }
        if let v = payload.leftArmLeanKg { values[TrendMetric.leftArmLean.rawValue] = toMass(v) }
        if let v = payload.trunkLeanKg { values[TrendMetric.trunkLean.rawValue] = toMass(v) }
        if let v = payload.rightLegLeanKg { values[TrendMetric.rightLegLean.rawValue] = toMass(v) }
        if let v = payload.leftLegLeanKg { values[TrendMetric.leftLegLean.rawValue] = toMass(v) }

        if let v = payload.rightArmFatKg { values[TrendMetric.rightArmFat.rawValue] = toMass(v) }
        if let v = payload.leftArmFatKg { values[TrendMetric.leftArmFat.rawValue] = toMass(v) }
        if let v = payload.trunkFatKg { values[TrendMetric.trunkFat.rawValue] = toMass(v) }
        if let v = payload.rightLegFatKg { values[TrendMetric.rightLegFat.rawValue] = toMass(v) }
        if let v = payload.leftLegFatKg { values[TrendMetric.leftLegFat.rawValue] = toMass(v) }

        return values
    }

    func buildPayload() throws -> InBodyPayload {
        func f(_ key: String) -> Double? { Double(fields[key, default: ""]) }

        // The review form displays mass values in the user's preferred unit
        // (see ScanEntryFlow labels). The parser extracts raw numbers from the
        // printout, which matches the user's unit setting on their InBody. Here
        // we convert back to kg for canonical storage — ScanDetailView reads
        // payload.weightKg as kg and re-formats for display.
        let massPref = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        let toKg: (Double) -> Double = { v in
            massPref == "kg" ? v : UnitConversion.lbToKg(v)
        }
        let optToKg: (Double?) -> Double? = { v in
            guard let v else { return nil }
            return massPref == "kg" ? v : UnitConversion.lbToKg(v)
        }

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
            weightKg: toKg(w),
            skeletalMuscleMassKg: toKg(smm),
            bodyFatMassKg: toKg(bfm),
            bodyFatPct: bf,
            totalBodyWaterL: tbw,
            bmi: b,
            basalMetabolicRate: bmr
        )
        payload.intracellularWaterL = f("intracellularWaterL")
        payload.extracellularWaterL = f("extracellularWaterL")
        payload.dryLeanMassKg = optToKg(f("dryLeanMassKg"))
        payload.leanBodyMassKg = optToKg(f("leanBodyMassKg"))
        payload.inBodyScore = f("inBodyScore")
        payload.rightArmLeanKg = optToKg(f("rightArmLeanKg"))
        payload.leftArmLeanKg = optToKg(f("leftArmLeanKg"))
        payload.trunkLeanKg = optToKg(f("trunkLeanKg"))
        payload.rightLegLeanKg = optToKg(f("rightLegLeanKg"))
        payload.leftLegLeanKg = optToKg(f("leftLegLeanKg"))
        payload.rightArmFatKg = optToKg(f("rightArmFatKg"))
        payload.leftArmFatKg = optToKg(f("leftArmFatKg"))
        payload.trunkFatKg = optToKg(f("trunkFatKg"))
        payload.rightLegFatKg = optToKg(f("rightLegFatKg"))
        payload.leftLegFatKg = optToKg(f("leftLegFatKg"))
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
