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

        let config = LaunchConfiguration.current

        #if DEBUG
        if config.isUITesting {
            let schema = Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self, SyncState.self, Goal.self])
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [memConfig])
            } catch {
                Log.app.error("In-memory UI-test store configuration failed", error)
                fatalError("Failed to configure in-memory UI-test store: \(error)")
            }
            TestDataSeeder.seed(profile: config.seedProfile, into: modelContainer.mainContext, referenceDate: Date())

            self.mirror = NoOpOutboundMirror()
            SyncHelper.mirror = self.mirror

            _appState = State(initialValue: Self.makePreloadedState(context: modelContainer.mainContext))
            return
        }
        #endif

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
                Goal.self
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

        _appState = State(initialValue: Self.makePreloadedState(context: modelContainer.mainContext))
    }

    /// Build the AppState with view models preloaded synchronously during app
    /// init, while we already have the ModelContainer in scope. MainTabView
    /// reads these off AppState and passes them into each tab via the
    /// `viewModel:` initializer, so the tab's @State is populated BEFORE its
    /// first body eval — no "render empty, then reflow to populated" flash mid
    /// tab-switch cross-fade. Shared by the production and UI-test launch
    /// paths so both exercise the identical preload sequence.
    private static func makePreloadedState(context: ModelContext) -> AppState {
        let state = AppState()
        let trendsVM = TrendsViewModel(modelContext: context)
        trendsVM.refresh()
        state.preloadedTrendsVM = trendsVM
        state.preloadedGoalVM = GoalViewModel(modelContext: context)
        state.preloadedBodyVM = BodyViewModel(modelContext: context)
        return state
    }

    @State private var appState: AppState

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .task {
                    guard !LaunchConfiguration.current.isUITesting else { return }
                    try? Tips.configure([
                        .displayFrequency(.weekly)
                    ])
                }
                .task {
                    guard !LaunchConfiguration.current.isUITesting else { return }
                    await HealthKitManager.requestAuthorizationIfNeeded()
                }
                .task {
                    guard !LaunchConfiguration.current.isUITesting else { return }
                    await mirror.reconcile(context: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
