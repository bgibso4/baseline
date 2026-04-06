import SwiftUI

enum AppTab: Int, CaseIterable {
    case trends
    case now
    case body
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState: AppState?

    var body: some View {
        @Bindable var state = appState ?? AppState()
        TabView(selection: $state.selectedTab) {
            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.trends)

            NowView()
                .tabItem {
                    Label("Now", systemImage: "scalemass.fill")
                }
                .tag(AppTab.now)

            BodyView()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }
                .tag(AppTab.body)
        }
        .tint(CadreColors.accent)
        .preferredColorScheme(.dark)
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
    }
}

#Preview {
    MainTabView()
}
