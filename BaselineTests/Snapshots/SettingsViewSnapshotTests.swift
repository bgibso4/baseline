import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Baseline

private typealias Measurement = Baseline.Measurement

/// Snapshot tests for `SettingsView`.
///
/// Uses XCTest (not Swift Testing) because swift-snapshot-testing's
/// `assertSnapshot` integrates with XCTest's failure recording. Reference
/// images live in `__Snapshots__/SettingsViewSnapshotTests/` alongside this file.
///
/// Configuration: iPhone 13 Pro layout (consistent with other snapshot suites).
final class SettingsViewSnapshotTests: XCTestCase {

    /// Set to `true` locally to regenerate the reference image, then set back
    /// to `false` and commit both this file and the new reference PNG.
    private let isRecording = false

    @MainActor
    func testSettingsView_DarkMode() {
        let container = makeContainer()
        seedSampleData(into: container.mainContext)

        // Pre-configure some settings so the snapshot shows realistic values.
        let defaults = UserDefaults(suiteName: "SettingsSnapshotTest")!
        defaults.removePersistentDomain(forName: "SettingsSnapshotTest")
        defaults.set("Ben", forKey: "userName")
        defaults.set(5, forKey: "heightFeet")
        defaults.set(10, forKey: "heightInches")
        defaults.set("lb", forKey: "weightUnit")
        defaults.set("in", forKey: "lengthUnit")
        defaults.set("male", forKey: "gender")
        // Birthday: May 15, 1992
        let birthday = Calendar.current.date(from: DateComponents(year: 1992, month: 5, day: 15))!
        defaults.set(birthday.timeIntervalSince1970, forKey: "birthdayInterval")

        let vm = SettingsViewModel(defaults: defaults)
        let view = NavigationStack {
            SettingsView(viewModel: vm)
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

    /// Seed a few entries so delete confirmation counts are non-zero.
    private func seedSampleData(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            context.insert(WeightEntry(weight: 197.0 + Double(i) * 0.2, unit: "lb", date: date))
        }
        try? context.save()
    }
}
