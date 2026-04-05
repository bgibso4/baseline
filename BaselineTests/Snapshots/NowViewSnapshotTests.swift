import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

/// Snapshot tests for `NowView`.
///
/// Uses XCTest (not Swift Testing) because swift-snapshot-testing's
/// `assertSnapshot` integrates with XCTest's failure recording. Reference
/// images live in `__Snapshots__/NowViewSnapshotTests/` alongside this file.
///
/// Configuration: iPhone 13 Pro layout, dark mode, default Dynamic Type.
/// The app is dark-mode-only in v1, so no light variant is captured.
///
/// Async state note: `NowView` creates its `NowViewModel` in `.onAppear`
/// and calls `refresh()` synchronously. Snapshot rendering triggers `onAppear`
/// as part of its view hosting, so the rendered image captures the loaded
/// (post-refresh) state without needing an explicit delay.
final class NowViewSnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate the reference image, then set back
    /// to `false` and commit both this file and the new reference PNG.
    private let isRecording = false

    @MainActor
    func testNowView_DarkMode_iPhone17() {
        let container = makeContainer()
        seedFourteenDays(into: container.mainContext)

        let view = NowView()
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
            InBodyScan.self,
            BodyMeasurement.self,
            SyncState.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    /// Seed 14 days of realistic weights (lbs), trending slightly down with
    /// daily wobble. Today's entry is ~197.2 lb.
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
