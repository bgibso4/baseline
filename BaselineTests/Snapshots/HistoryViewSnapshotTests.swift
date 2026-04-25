import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// Snapshot tests for `HistoryView`.
///
/// Uses XCTest (not Swift Testing) to match swift-snapshot-testing's
/// XCTest-based failure recording. Reference images live in
/// `__Snapshots__/HistoryViewSnapshotTests/` alongside this file.
///
/// Determinism: fixtures are seeded at fixed day offsets from real `today`
/// so relative weekday labels stay meaningful, while the injected VM is
/// pre-refreshed so the snapshot doesn't race `.onAppear`.
final class HistoryViewSnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate the reference image, then set back
    /// to `false` and commit both this file and the new reference PNG.
    private let isRecording = false

    @MainActor
    func testHistoryView_DarkMode_iPhone13Pro() throws {
        let container = makeContainer()
        seedFiveEntries(into: container.mainContext)

        let vm = HistoryViewModel(modelContext: container.mainContext)
        vm.refresh()

        let view = NavigationStack {
            HistoryView(viewModel: vm)
        }
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

    /// Five hand-picked entries spanning five days — mixed deltas
    /// (up, down, flat) so the snapshot exercises positive/negative/neutral
    /// delta coloring.
    private func seedFiveEntries(into context: ModelContext) {
        let weights: [Double] = [197.0, 197.2, 197.0, 196.8, 197.1]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for (i, weight) in weights.enumerated() {
            let daysAgo = weights.count - 1 - i
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            context.insert(WeightEntry(weight: weight, unit: "lb", date: date))
        }
        try! context.save()
    }
}
