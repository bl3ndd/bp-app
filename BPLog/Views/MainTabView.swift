import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "heart.text.square") { HomeView() }
            Tab("History", systemImage: "list.bullet") { HistoryView() }
            Tab("Charts", systemImage: "chart.xyaxis.line") { ChartView() }
            Tab("Stats", systemImage: "chart.bar.xaxis") { StatsView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
    }
}
