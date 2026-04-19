import XCTest
import SwiftData
@testable import Baseline

final class ScanEntryViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, Scan.self, Baseline.Measurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        // Tests assert literal kg values, so pin the unit preference.
        // Production default is "lb", which would trigger a lb→kg conversion
        // in buildPayload and make the assertions fail.
        UserDefaults.standard.set("kg", forKey: "weightUnit")
    }

    override func tearDown() {
        container = nil
        context = nil
        UserDefaults.standard.removeObject(forKey: "weightUnit")
        super.tearDown()
    }

    // MARK: - State Machine Navigation

    func testInitialStepIsSelectType() {
        let vm = ScanEntryViewModel(modelContext: context)
        XCTAssertEqual(vm.currentStep, .selectType)
    }

    func testSelectTypeAdvancesToSelectMethod() {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectType(.inBody)
        XCTAssertEqual(vm.currentStep, .selectMethod)
        XCTAssertEqual(vm.selectedType, .inBody)
    }

    func testSelectMethodCameraAdvancesToCamera() {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectType(.inBody)
        vm.selectMethod(camera: true)
        XCTAssertEqual(vm.currentStep, .camera)
        XCTAssertEqual(vm.selectedSource, .ocr)
    }

    func testSelectMethodManualAdvancesToManualEntry() {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectType(.inBody)
        vm.selectMethod(camera: false)
        XCTAssertEqual(vm.currentStep, .manualEntry)
        XCTAssertEqual(vm.selectedSource, .manual)
    }

    func testGoBackFromSelectMethod() {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectType(.inBody)
        XCTAssertEqual(vm.currentStep, .selectMethod)
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .selectType)
    }

    func testGoBackFromCamera() {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectType(.inBody)
        vm.selectMethod(camera: true)
        XCTAssertEqual(vm.currentStep, .camera)
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .selectMethod)
    }

    func testGoBackFromManualEntry() {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectType(.inBody)
        vm.selectMethod(camera: false)
        XCTAssertEqual(vm.currentStep, .manualEntry)
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .selectMethod)
    }

    // MARK: - Field Population from Parse Result

    func testPopulateFieldsFromParseResult() {
        let vm = ScanEntryViewModel(modelContext: context)

        var result = InBodyParseResult()
        result.weightKg = 89.5
        result.skeletalMuscleMassKg = 40.2
        result.bodyFatMassKg = 15.3
        result.bodyFatPct = 17.1
        result.totalBodyWaterL = 54.0
        result.bmi = 24.1
        result.basalMetabolicRate = 1842
        result.intracellularWaterL = 33.5
        result.rightArmLeanKg = 3.8
        result.confidence = ["weightKg": 0.95, "bmi": 0.5]

        vm.populateFields(from: result)

        XCTAssertEqual(vm.weightKg, "89.5")
        XCTAssertEqual(vm.skeletalMuscleMassKg, "40.2")
        XCTAssertEqual(vm.bodyFatMassKg, "15.3")
        XCTAssertEqual(vm.bodyFatPct, "17.1")
        XCTAssertEqual(vm.totalBodyWaterL, "54")
        XCTAssertEqual(vm.bmi, "24.1")
        XCTAssertEqual(vm.basalMetabolicRate, "1842")
        XCTAssertEqual(vm.fieldValue("intracellularWaterL"), "33.5")
        XCTAssertEqual(vm.fieldValue("rightArmLeanKg"), "3.8")

        // Low confidence flagging
        XCTAssertTrue(vm.lowConfidenceFields.contains("bmi"), "BMI should be flagged as low confidence")
        XCTAssertFalse(vm.lowConfidenceFields.contains("weightKg"), "Weight should NOT be flagged")
    }

    // MARK: - canSave

    func testCanSaveRequiresAllCoreFields() {
        let vm = ScanEntryViewModel(modelContext: context)
        XCTAssertFalse(vm.canSave)

        vm.weightKg = "89.5"
        vm.skeletalMuscleMassKg = "40.2"
        vm.bodyFatMassKg = "15.3"
        vm.bodyFatPct = "17.1"
        vm.totalBodyWaterL = "54.0"
        vm.bmi = "24.1"
        XCTAssertFalse(vm.canSave, "Missing BMR — should not be saveable")

        vm.basalMetabolicRate = "1842"
        XCTAssertTrue(vm.canSave)
    }

    // MARK: - Save

    func testSaveCreatesValidScan() throws {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.selectedType = .inBody
        vm.selectedSource = .manual

        // Populate required fields
        vm.weightKg = "89.5"
        vm.skeletalMuscleMassKg = "40.2"
        vm.bodyFatMassKg = "15.3"
        vm.bodyFatPct = "17.1"
        vm.totalBodyWaterL = "54.0"
        vm.bmi = "24.1"
        vm.basalMetabolicRate = "1842"

        // Populate some optional fields
        vm.setField("intracellularWaterL", value: "33.5")
        vm.setField("rightArmLeanKg", value: "3.8")

        try vm.save()

        let descriptor = FetchDescriptor<Scan>()
        let scans = try context.fetch(descriptor)
        XCTAssertEqual(scans.count, 1)

        let scan = scans.first!
        XCTAssertEqual(scan.scanType, .inBody)
        XCTAssertEqual(scan.scanSource, .manual)

        let decoded = try scan.decoded()
        if case .inBody(let payload) = decoded {
            XCTAssertEqual(payload.weightKg, 89.5)
            XCTAssertEqual(payload.skeletalMuscleMassKg, 40.2)
            XCTAssertEqual(payload.bodyFatMassKg, 15.3)
            XCTAssertEqual(payload.bodyFatPct, 17.1)
            XCTAssertEqual(payload.totalBodyWaterL, 54.0)
            XCTAssertEqual(payload.bmi, 24.1)
            XCTAssertEqual(payload.basalMetabolicRate, 1842)
            XCTAssertEqual(payload.intracellularWaterL, 33.5)
            XCTAssertEqual(payload.rightArmLeanKg, 3.8)
            XCTAssertNil(payload.leftArmLeanKg, "Unpopulated optional should be nil")
        } else {
            XCTFail("Expected inBody payload")
        }
    }

    func testSaveThrowsWhenMissingRequiredFields() {
        let vm = ScanEntryViewModel(modelContext: context)
        vm.weightKg = "89.5"
        // Missing other required fields

        XCTAssertThrowsError(try vm.save()) { error in
            guard let saveError = error as? ScanEntryViewModel.SaveError,
                  case .missingRequiredFields(let fields) = saveError else {
                XCTFail("Expected missingRequiredFields error")
                return
            }
            XCTAssertTrue(fields.contains("Skeletal Muscle Mass"))
            XCTAssertTrue(fields.contains("BMI"))
        }
    }

    // MARK: - New Fields, Retry, and Scan Date

    func testPopulateFields_SetsNewFields() {
        let vm = ScanEntryViewModel(modelContext: context)
        var result = InBodyParseResult()
        result.ecwTbwRatio = 0.380
        result.skeletalMuscleIndex = 10.4
        result.visceralFatLevel = 3
        result.rightArmLeanPct = 112.4
        result.trunkFatPct = 94.5
        result.scanDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15))

        vm.populateFields(from: result)

        XCTAssertEqual(vm.fieldValue("ecwTbwRatio"), "0.380")
        XCTAssertEqual(vm.fieldValue("skeletalMuscleIndex"), "10.4")
        XCTAssertEqual(vm.fieldValue("visceralFatLevel"), "3")
        XCTAssertEqual(vm.fieldValue("rightArmLeanPct"), "112.4")
        XCTAssertEqual(vm.fieldValue("trunkFatPct"), "94.5")
        XCTAssertNotNil(vm.scanDate)
    }

    func testRetryMerge_PreservesUserEdits() {
        let vm = ScanEntryViewModel(modelContext: context)

        var result1 = InBodyParseResult()
        result1.weightKg = 60.0
        result1.confidence["weightKg"] = 0.5
        vm.populateFields(from: result1)

        vm.weightKg = "61.5"
        vm.markFieldEdited("weightKg")

        var result2 = InBodyParseResult()
        result2.weightKg = 62.0
        result2.confidence["weightKg"] = 0.9
        result2.bmi = 25.0
        result2.confidence["bmi"] = 0.8

        vm.mergeRetryResult(result2)

        XCTAssertEqual(vm.weightKg, "61.5")
        XCTAssertEqual(vm.bmi, "25")
    }

    func testRetryCount_TracksAttempts() {
        let vm = ScanEntryViewModel(modelContext: context)
        XCTAssertEqual(vm.retryCount, 0)
        vm.retryCount += 1
        XCTAssertEqual(vm.retryCount, 1)
    }

    // MARK: - Edit Mode

    func testLoadForEdit_SeedsAllFieldsWithKgUnits() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        let payload = InBodyPayload(
            weightKg: 80.0,
            skeletalMuscleMassKg: 38.0,
            bodyFatMassKg: 16.0,
            bodyFatPct: 20.0,
            totalBodyWaterL: 48.0,
            bmi: 24.0,
            basalMetabolicRate: 1800,
            intracellularWaterL: 30.0,
            extracellularWaterL: 18.0,
            dryLeanMassKg: 14.0,
            leanBodyMassKg: 62.0,
            inBodyScore: 76,
            rightArmLeanKg: 3.5,
            leftArmLeanKg: 3.4,
            trunkLeanKg: 29.0,
            rightLegLeanKg: 10.1,
            leftLegLeanKg: 10.0,
            rightArmFatKg: 0.9,
            leftArmFatKg: 0.9,
            trunkFatKg: 8.0,
            rightLegFatKg: 2.8,
            leftLegFatKg: 2.8,
            ecwTbwRatio: 0.378,
            skeletalMuscleIndex: 10.2,
            visceralFatLevel: 5,
            rightArmLeanPct: 110.0,
            leftArmLeanPct: 108.0,
            trunkLeanPct: 100.0,
            rightLegLeanPct: 102.0,
            leftLegLeanPct: 101.0,
            rightArmFatPct: 90.0,
            leftArmFatPct: 92.0,
            trunkFatPct: 110.0,
            rightLegFatPct: 95.0,
            leftLegFatPct: 96.0
        )
        let data = try JSONEncoder().encode(payload)
        let scanDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400))
        let scan = Scan(date: scanDate, type: .inBody, source: .ocr, payload: data)
        context.insert(scan)
        try context.save()

        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")

        XCTAssertTrue(vm.editingScan === scan)
        XCTAssertEqual(vm.currentStep, .manualEntry)
        XCTAssertEqual(vm.selectedType, .inBody)
        XCTAssertEqual(vm.selectedSource, .ocr)
        XCTAssertEqual(vm.scanDate, scanDate)
        XCTAssertEqual(vm.weightKg, "80")
        XCTAssertEqual(vm.skeletalMuscleMassKg, "38")
        XCTAssertEqual(vm.bodyFatPct, "20")
        XCTAssertEqual(vm.bmi, "24")
        XCTAssertEqual(vm.basalMetabolicRate, "1800")
        XCTAssertEqual(vm.fieldValue("rightArmLeanKg"), "3.5")
        XCTAssertEqual(vm.fieldValue("ecwTbwRatio"), "0.378")
        XCTAssertEqual(vm.fieldValue("visceralFatLevel"), "5")
    }

    func testLoadForEdit_ConvertsMassFieldsToLbWhenPrefIsLb() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        let payload = InBodyPayload(
            weightKg: 80.0,
            skeletalMuscleMassKg: 38.0,
            bodyFatMassKg: 16.0,
            bodyFatPct: 20.0,
            totalBodyWaterL: 48.0,
            bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)
        context.insert(scan)

        vm.loadForEdit(scan: scan, payload: payload, massPref: "lb")

        // 80 kg → 176.37 lb
        let expectedLb = UnitConversion.kgToLb(80.0)
        let weightLb = try XCTUnwrap(Double(vm.weightKg))
        XCTAssertEqual(weightLb, expectedLb, accuracy: 0.1)
        // Non-mass fields stay the same
        XCTAssertEqual(vm.bodyFatPct, "20")
        XCTAssertEqual(vm.bmi, "24")
    }

    func testLoadForEdit_LeavesEmptyStringForMissingOptionals() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        let payload = InBodyPayload(
            weightKg: 80.0,
            skeletalMuscleMassKg: 38.0,
            bodyFatMassKg: 16.0,
            bodyFatPct: 20.0,
            totalBodyWaterL: 48.0,
            bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)
        context.insert(scan)

        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")

        XCTAssertEqual(vm.fieldValue("rightArmLeanKg"), "")
        XCTAssertEqual(vm.fieldValue("ecwTbwRatio"), "")
        XCTAssertEqual(vm.fieldValue("visceralFatLevel"), "")
        XCTAssertEqual(vm.fieldValue("inBodyScore"), "")
    }
}
