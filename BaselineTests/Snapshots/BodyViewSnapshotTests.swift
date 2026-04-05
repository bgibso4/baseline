import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// Snapshot tests for `BodyView`.
///
/// Uses XCTest (not Swift Testing) because swift-snapshot-testing's
/// `assertSnapshot` integrates with XCTest's failure recording. Reference
/// images live in `__Snapshots__/BodyViewSnapshotTests/` alongside this file.
///
/// Configuration: iPhone 13 Pro layout (same as NowViewSnapshotTests).
///
/// Determinism: fixtures use fixed dates relative to today, and the test
/// injects a pre-loaded `BodyViewModel` so the snapshot doesn't depend on
/// `.onAppear` timing.
final class BodyViewSnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate the reference image, then set back
    /// to `false` and commit both this file and the new reference PNG.
    private let isRecording = false

    @MainActor
    func testBodyView_DarkMode_WithData() {
        let container = makeContainer()
        seedScanAndMeasurements(into: container.mainContext)

        let vm = BodyViewModel(modelContext: container.mainContext)
        vm.refresh()

        let view = BodyView(viewModel: vm)
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
    func testBodyView_DarkMode_EmptyState() {
        let container = makeContainer()

        let vm = BodyViewModel(modelContext: container.mainContext)
        vm.refresh()

        let view = BodyView(viewModel: vm)
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

    /// Seed one InBody scan + several tape measurements for a realistic Body tab.
    private func seedScanAndMeasurements(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // InBody scan from 5 days ago
        let scanDate = calendar.date(byAdding: .day, value: -5, to: today)!
        let payload = InBodyPayload(
            weightKg: 89.5,
            skeletalMuscleMassKg: 73.7,
            bodyFatMassKg: 15.4,
            bodyFatPct: 17.2,
            totalBodyWaterL: 54.3,
            bmi: 24.1,
            basalMetabolicRate: 1842,
            leanBodyMassKg: 74.1,
            inBodyScore: 82
        )
        let payloadData = try! JSONEncoder().encode(payload)
        let scan = Scan(date: scanDate, type: .inBody, source: .manual, payload: payloadData)
        context.insert(scan)

        // Tape measurements from 2 days ago
        let measDate = calendar.date(byAdding: .day, value: -2, to: today)!
        let measurements: [(MeasurementType, Double)] = [
            (.waist, 87.6),     // ~34.5 in
            (.hips, 101.6),     // ~40.0 in
            (.chest, 106.7),    // ~42.0 in
            (.neck, 40.6),      // ~16.0 in
            (.armLeft, 38.1),   // ~15.0 in
            (.armRight, 38.4),  // ~15.1 in
        ]
        for (type, valueCm) in measurements {
            let m = Measurement(date: measDate, type: type, valueCm: valueCm)
            context.insert(m)
        }

        try! context.save()
    }
}
