import SwiftUI
import SwiftData
import TipKit

private typealias BaselineMeasurement = Baseline.Measurement

@main
struct BaselineApp: App {
    let modelContainer: ModelContainer
    let mirror: OutboundMirror

    /// Shared App Group container URL for SwiftData store.
    /// Both the main app and the widget extension read from this location.
    static let appGroupURL: URL = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.cadre.baseline")!
            .appendingPathComponent("Baseline.store")
    }()

    init() {
        DecimalPadDoneBar.install()
        CloudKitSyncMonitor.start()

        // User data — syncs to iCloud via CloudKit, stored in shared App Group container
        let cloudSchema = Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self, Goal.self])
        let cloudConfig = ModelConfiguration(
            "Baseline",
            schema: cloudSchema,
            url: BaselineApp.appGroupURL,
            cloudKitDatabase: .automatic
        )

        // Local-only — sync bookkeeping, not synced to iCloud
        let localSchema = Schema([SyncState.self])
        let localConfig = ModelConfiguration(
            "BaselineLocal",
            schema: localSchema,
            cloudKitDatabase: .none
        )

        do {
            let fullSchema = Schema([
                WeightEntry.self,
                Scan.self,
                BaselineMeasurement.self,
                SyncState.self,
                Goal.self,
            ])
            modelContainer = try ModelContainer(
                for: fullSchema,
                configurations: [cloudConfig, localConfig]
            )
        } catch {
            fatalError("Failed to configure SwiftData: \(error)")
        }

        // Public build: NoOp. Future Cadre build will inject CloudflareOutboundMirror.
        let outboundMirror: OutboundMirror = NoOpOutboundMirror()
        self.mirror = outboundMirror
        SyncHelper.mirror = outboundMirror
    }

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.weekly)
                    ])
                }
                .task {
                    await HealthKitManager.requestAuthorizationIfNeeded()
                }
                .task {
                    await mirror.reconcile(context: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
