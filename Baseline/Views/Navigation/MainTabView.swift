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
            TrendsPlaceholder()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.trends)

            NowView()
                .tabItem {
                    Label("Now", systemImage: "scalemass.fill")
                }
                .tag(AppTab.now)

            BodyPlaceholder()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }
                .tag(AppTab.body)
        }
        .tint(CadreColors.accent)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Placeholder screens (replaced in later tasks)

private struct TrendsPlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()
                Text("Trends")
                    .font(CadreTypography.title)
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .navigationTitle("Trends")
        }
    }
}

private struct BodyPlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()
                Text("Body")
                    .font(CadreTypography.title)
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .navigationTitle("Body")
        }
    }
}

#Preview {
    MainTabView()
}
