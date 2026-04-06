import SwiftUI
import SwiftData

private typealias BaselineMeasurement = Baseline.Measurement

@main
struct BaselineApp: App {
    let modelContainer: ModelContainer
    let mirror: OutboundMirror

    init() {
        // User data — syncs to iCloud via CloudKit
        let cloudSchema = Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self])
        let cloudConfig = ModelConfiguration(
            "Baseline",
            schema: cloudSchema,
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

    var body: some Scene {
        WindowGroup {
            MainTabView()
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
