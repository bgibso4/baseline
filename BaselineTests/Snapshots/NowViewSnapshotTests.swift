import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// Snapshot tests for `NowView`.
///
/// Uses XCTest (not Swift Testing) because swift-snapshot-testing's
/// `assertSnapshot` integrates with XCTest's failure recording. Reference
/// images live in `__Snapshots__/NowViewSnapshotTests/` alongside this file.
///
/// Configuration: iPhone 13 Pro layout (swift-snapshot-testing's highest
/// available iPhone preset — the simulator the suite runs on is iPhone 17,
/// but the snapshot library ships with `.iPhone13Pro` and we capture to that
/// layout for stable, device-agnostic references).
///
/// Determinism: fixtures are seeded at fixed offsets from a reference date,
/// and the test injects a pre-loaded `NowViewModel` so the snapshot doesn't
/// depend on `.onAppear` timing.
final class NowViewSnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate the reference image, then set back
    /// to `false` and commit both this file and the new reference PNG.
    private let isRecording = false

    @MainActor
    func testNowView_DarkMode_iPhone13Pro() throws {
        let container = makeContainer()
        seedFourteenDays(into: container.mainContext)

        // Pre-load the VM synchronously so the snapshot renders against fully
        // populated data (no .onAppear race).
        let vm = NowViewModel(modelContext: container.mainContext)
        vm.refresh()

        let view = NowView(viewModel: vm)
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

    /// Seed 14 days of realistic weights (lbs), trending slightly down with
    /// daily wobble. Today's entry is ~197.2 lb.
    ///
    /// The 13 historical entries use fixed offsets from real "today"
    /// (`startOfDay(Date())`), and today's entry is anchored to real today so
    /// `NowViewModel`'s internal `Date()`-based "today" predicate still
    /// matches. Offsets are the only time-dependent piece; the values
    /// themselves are hand-picked so derived stats (min/avg/max) stay stable
    /// across runs.
    private func seedFourteenDays(into context: ModelContext) {
        // Deterministic series (hand-picked, no RNG) so snapshots stay stable.
        let weights: [Double] = [
            199.4, 199.8, 198.6, 199.1, 198.2, 198.7, 197.9,
            198.4, 197.6, 198.0, 197.3, 197.8, 196.9, 197.2
        ]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for (i, weight) in weights.enumerated() {
            // index 0 = 13 days ago, last index = today
            let daysAgo = weights.count - 1 - i
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let entry = WeightEntry(weight: weight, unit: "lb", date: date)
            context.insert(entry)
        }
        try! context.save()
    }
}
