import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// Snapshot tests for `TrendsView`.
///
/// Uses XCTest so `assertSnapshot` can record failures. Fixtures are seeded
/// at fixed offsets from `Date()`, and the VM is pre-loaded and injected so
/// snapshots don't depend on `.onAppear` timing.
final class TrendsViewSnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate the reference image, then set back
    /// to `false` and commit both this file and the new reference PNG.
    private let isRecording = false

    // MARK: - Default (30 days of entries, M range active)

    @MainActor
    func testTrendsView_DarkMode_DefaultMonth() throws {
        let container = makeContainer()
        seedThirtyDays(into: container.mainContext)

        let vm = TrendsViewModel(modelContext: container.mainContext)
        vm.timeRange = .month
        vm.refresh()

        let view = TrendsView(viewModel: vm)
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

    // MARK: - Empty state (no entries)

    @MainActor
    func testTrendsView_DarkMode_EmptyState() throws {
        let container = makeContainer()

        let vm = TrendsViewModel(modelContext: container.mainContext)
        vm.timeRange = .month
        vm.refresh()

        let view = TrendsView(viewModel: vm)
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

    /// Seed 30 days of deterministic daily weights (lbs), trending slightly
    /// down with small daily wobble. Values are hand-picked so min/max/moving
    /// average stay stable across runs.
    private func seedThirtyDays(into context: ModelContext) {
        let weights: [Double] = [
            200.2, 200.4, 199.9, 200.1, 199.6, 199.8, 199.3,
            199.5, 198.9, 199.2, 198.7, 199.0, 198.5, 198.8,
            198.2, 198.6, 198.0, 198.3, 197.7, 198.1, 197.5,
            197.9, 197.3, 197.6, 197.1, 197.4, 196.9, 197.2,
            196.7, 197.4
        ]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for (i, weight) in weights.enumerated() {
            // index 0 = 29 days ago, last index = today
            let daysAgo = weights.count - 1 - i
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let entry = WeightEntry(weight: weight, unit: "lb", date: date)
            context.insert(entry)
        }
        try! context.save()
    }
}
