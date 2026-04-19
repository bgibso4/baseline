import SwiftUI
import SwiftData
import TipKit
import UIKit

private typealias BaselineMeasurement = Baseline.Measurement

/// App-wide orientation lock. The whole app is portrait by default;
/// individual screens (currently only Trends fullscreen) can temporarily
/// request landscape by flipping `allowLandscape` and calling
/// `UIWindowScene.requestGeometryUpdate`.
final class BaselineAppDelegate: NSObject, UIApplicationDelegate {
    static var allowLandscape = false

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        BaselineAppDelegate.allowLandscape ? .landscape : .portrait
    }
}

@main
struct BaselineApp: App {
    @UIApplicationDelegateAdaptor(BaselineAppDelegate.self) var appDelegate
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
        Log.app.info("Baseline launching")
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
            Log.app.error("SwiftData configuration failed", error)
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
