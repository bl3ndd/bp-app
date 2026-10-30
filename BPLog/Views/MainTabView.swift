import SwiftUI
import SwiftData

struct MainTabView: View {
    enum Page: Hashable { case home, history, charts, stats, settings }

    @Environment(AppSettings.self) private var settings
    @Query(sort: \Reading.date) private var readings: [Reading]
    @State private var page = Page.home

    var body: some View {
        TabView(selection: $page) {
            Tab("Home", systemImage: "heart.text.square", value: Page.home) { HomeView() }
            Tab("History", systemImage: "list.bullet", value: Page.history) { HistoryView() }
            Tab("Charts", systemImage: "chart.xyaxis.line", value: Page.charts) { ChartView() }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: Page.stats) { StatsView() }
            Tab("Settings", systemImage: "gearshape", value: Page.settings) { SettingsView() }
        }
        // A widget's "add" link lands on Home, which opens the entry form.
        .onChange(of: settings.pendingAddReading) { _, pending in
            if pending { page = .home }
        }
        .onAppear { WidgetBridge.publish(readings.map(\.value)) }
        .onChange(of: widgetFingerprint) { WidgetBridge.publish(readings.map(\.value)) }
    }

    /// Changes whenever a reading is added, deleted or edited, so the widget never shows stale numbers.
    private var widgetFingerprint: [Int] {
        [readings.count, readings.reduce(0) { $0 &+ $1.systolic &* 31 &+ $1.diastolic },
         Int(readings.last?.date.timeIntervalSince1970 ?? 0)]
    }
}
