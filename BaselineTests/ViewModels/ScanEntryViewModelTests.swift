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
    }

    override func tearDown() {
        container = nil
        context = nil
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
        XCTAssertEqual(vm.intracellularWaterL, "33.5")
        XCTAssertEqual(vm.rightArmLeanKg, "3.8")

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
        vm.intracellularWaterL = "33.5"
        vm.rightArmLeanKg = "3.8"

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

        XCTAssertEqual(vm.ecwTbwRatio, "0.380")
        XCTAssertEqual(vm.skeletalMuscleIndex, "10.4")
        XCTAssertEqual(vm.visceralFatLevel, "3")
        XCTAssertEqual(vm.rightArmLeanPct, "112.4")
        XCTAssertEqual(vm.trunkFatPct, "94.5")
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
}
