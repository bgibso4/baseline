import SwiftUI

enum AppTab: Int, CaseIterable {
    case trends
    case today
    case body
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TrendsPlaceholder()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.trends)

            TodayPlaceholder()
                .tabItem {
                    Label("Today", systemImage: "scalemass.fill")
                }
                .tag(AppTab.today)

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

private struct TodayPlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()
                Text("Today")
                    .font(CadreTypography.title)
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
    }
}

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
