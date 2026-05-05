
import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        TabView(selection: $store.selectedMainTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }
                .tag(MainTab.dashboard)

            LoadsListView()
                .tabItem { Label("Loads", systemImage: "bolt.horizontal.fill") }
                .tag(MainTab.loads)

            BalanceView()
                .tabItem { Label("Balance", systemImage: "arrow.left.arrow.right") }
                .tag(MainTab.balance)

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.xyaxis.line") }
                .tag(MainTab.analytics)

            ProjectsHomeView()
                .tabItem { Label("Projects", systemImage: "folder.fill") }
                .tag(MainTab.projects)
        }
        .tint(PCColor.dataBlue)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(red: 27 / 255, green: 33 / 255, blue: 53 / 255, alpha: 1)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
