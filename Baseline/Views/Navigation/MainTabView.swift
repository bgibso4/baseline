import SwiftUI

enum AppTab: Int, CaseIterable {
    case trends
    case now
    case body
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .now

    var body: some View {
        TabView(selection: $selectedTab) {
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
    }
}

#Preview {
    MainTabView()
}
