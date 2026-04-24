import SwiftUI

enum AppTab: Int, CaseIterable {
    case trends
    case now
    case body
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState: AppState?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var state = appState ?? AppState()
        // Pass the preloaded VMs (created synchronously in BaselineApp.init)
        // into each tab's `viewModel:` initializer so the tab's @State is
        // seeded before first body evaluation. Without this, the tab's
        // @State starts as nil, onAppear populates it, and the layout
        // reflows from empty-placeholder to real data — which gets
        // captured mid cross-fade on first tab switch.
        let preloadedTrendsVM = appState?.preloadedTrendsVM as? TrendsViewModel
        let preloadedBodyVM = appState?.preloadedBodyVM as? BodyViewModel

        return TabView(selection: $state.selectedTab) {
            // .compositingGroup() on each tab flattens the view hierarchy into
            // a single render layer before opacity is applied. iOS 26's TabView
            // cross-fades between tabs by animating each view's opacity — without
            // compositing, every sublayer (gradient background, arc, text) fades
            // independently and the previous tab bleeds through. With compositing,
            // the fade reads as a clean A→B swap.
            TrendsView(preloadedVM: preloadedTrendsVM)
                .compositingGroup()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.trends)

            NowView()
                .compositingGroup()
                .tabItem {
                    Label("Now", systemImage: "scalemass.fill")
                }
                .tag(AppTab.now)

            BodyView(preloadedVM: preloadedBodyVM)
                .compositingGroup()
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
