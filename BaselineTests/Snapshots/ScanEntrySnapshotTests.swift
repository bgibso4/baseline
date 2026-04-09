import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

/// Snapshot tests for the scan entry flow.
///
/// Uses XCTest (not Swift Testing) because swift-snapshot-testing's
/// `assertSnapshot` integrates with XCTest's failure recording.
///
/// Configuration: iPhone 13 Pro layout (consistent with other snapshot tests).
final class ScanEntrySnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate reference images.
    private let isRecording = true

    @MainActor
    func testScanEntry_TypeSelection() {
        let container = makeContainer()
        let vm = ScanEntryViewModel(modelContext: container.mainContext)
        // Step defaults to .selectType

        let view = ScanEntryFlow(viewModel: vm)
            .modelContainer(container)

        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: .iPhone13Pro),
                traits: UITraitCollection(userInterfaceStyle: .dark)
            ),
            record: isRecording
        )
    }

    @MainActor
    func testScanEntry_ManualForm() {
        let container = makeContainer()
        let vm = ScanEntryViewModel(modelContext: container.mainContext)
        // Advance to manual entry step
        vm.selectType(.inBody)
        vm.selectMethod(camera: false)

        let view = ScanEntryFlow(viewModel: vm)
            .modelContainer(container)

        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: .iPhone13Pro),
                traits: UITraitCollection(userInterfaceStyle: .dark)
            ),
            record: isRecording
        )
    }

    @MainActor
    func testScanEntry_ReviewForm_WithLowConfidence() {
        let container = makeContainer()
        let vm = ScanEntryViewModel(modelContext: container.mainContext)
        // Populate with sample OCR data including low-confidence fields
        var parseResult = InBodyParseResult()
        parseResult.weightKg = 82.5
        parseResult.skeletalMuscleMassKg = 38.2
        parseResult.bodyFatMassKg = 18.4
        parseResult.bodyFatPct = 22.3
        parseResult.totalBodyWaterL = 46.1
        parseResult.bmi = 24.7
        parseResult.basalMetabolicRate = 1820
        parseResult.inBodyScore = 74
        parseResult.ecwTbwRatio = 0.381
        parseResult.confidence = [
            "weightKg": 0.95,
            "skeletalMuscleMassKg": 0.88,
            "bodyFatMassKg": 0.60,  // below threshold — flagged
            "bodyFatPct": 0.55,     // below threshold — flagged
            "totalBodyWaterL": 0.91,
            "bmi": 0.93,
            "basalMetabolicRate": 0.50  // below threshold — flagged
        ]
        vm.populateFields(from: parseResult)
        vm.currentStep = .review

        let view = ScanEntryFlow(viewModel: vm)
            .modelContainer(container)

        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: .iPhone13Pro),
                traits: UITraitCollection(userInterfaceStyle: .dark)
            ),
            record: isRecording
        )
    }

    // MARK: - Helpers

    private func makeContainer() -> ModelContainer {
        let schema = Schema([
            WeightEntry.self,
            Scan.self,
            Baseline.Measurement.self,
            SyncState.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
