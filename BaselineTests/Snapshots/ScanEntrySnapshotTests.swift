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
    private let isRecording = false

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
