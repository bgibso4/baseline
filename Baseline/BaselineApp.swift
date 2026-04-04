import SwiftUI
import SwiftData

@main
struct BaselineApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                WeightEntry.self,
                InBodyScan.self,
                BodyMeasurement.self,
                SyncState.self,
            ])
            let config = ModelConfiguration(
                "Baseline",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to configure SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
    }
}
