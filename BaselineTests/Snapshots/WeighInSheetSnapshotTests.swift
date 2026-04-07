import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// Snapshot tests for `WeighInSheet`.
///
/// Sheet content is rendered inside a fixed-layout frame that approximates a
/// medium detent, since we're snapshotting the sheet body directly (not the
/// full device chrome with its presentation).
final class WeighInSheetSnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate the reference image.
    private let isRecording = false

    @MainActor
    func testWeighInSheet_DarkMode_Default() {
        let container = makeContainer()
        let vm = WeighInViewModel(
            modelContext: container.mainContext,
            lastWeight: 197.4,
            unit: "lb"
        )

        let view = WeighInSheet(
            lastWeight: 197.4,
            unit: "lb",
            viewModel: vm
        )
        .frame(width: 390, height: 500)
        .background(CadreColors.bg)
        .modelContainer(container)

        assertSnapshot(
            of: view,
            as: .image(
                layout: .fixed(width: 390, height: 500),
                traits: UITraitCollection(userInterfaceStyle: .dark)
            ),
            record: isRecording
        )
    }

    // MARK: - Fixtures

    private func makeContainer() -> ModelContainer {
        let schema = Schema([
            WeightEntry.self,
            Scan.self,
            Measurement.self,
            SyncState.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
