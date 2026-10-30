import Foundation
import WidgetKit

/// What the widget shows, written by the app into the shared App Group.
/// The widget target keeps an identical copy (BPLogWidget/WidgetSnapshot.swift):
/// change both together.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    var systolic: Int
    var diastolic: Int
    var pulse: Int?
    var date: Date
    var categoryRaw: Int
    var categoryTitle: String
    /// Mean of daily averages over the last 7 days, like Home's card.
    var weekSystolic: Int?
    var weekDiastolic: Int?
}

/// App side of the widget: publishes the snapshot and recognizes its links.
/// The App Group container is local to the device, not iCloud (guideline 5.1.3(ii)).
enum WidgetBridge {
    static let appGroup = "group.white.tea.BPLog"
    static let snapshotKey = "widgetSnapshot"

    nonisolated static func snapshot(_ readings: [ReadingValue], now: Date, calendar: Calendar) -> WidgetSnapshot? {
        guard let last = readings.max(by: { $0.date < $1.date }) else { return nil }
        let since = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? .distantPast
        let week = StatsEngine.averages(StatsEngine.daily(readings.filter { $0.date >= since }, calendar: calendar))
        return WidgetSnapshot(systolic: last.systolic, diastolic: last.diastolic, pulse: last.pulse, date: last.date,
                              categoryRaw: last.category.rawValue, categoryTitle: last.category.title,
                              weekSystolic: week.map { Int($0.systolic.rounded()) },
                              weekDiastolic: week.map { Int($0.diastolic.rounded()) })
    }

    /// Writes the snapshot (or clears it when there are no readings) and asks widgets to redraw.
    static func publish(_ readings: [ReadingValue]) {
        guard !LaunchMode.isThrowaway, let defaults = UserDefaults(suiteName: appGroup) else { return }
        if let snapshot = snapshot(readings, now: Date(), calendar: .current),
           let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        } else {
            defaults.removeObject(forKey: snapshotKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// `simplybp://add`: open the app straight on the Add Reading form.
    nonisolated static func isAddLink(_ url: URL) -> Bool {
        url.scheme == "simplybp" && url.host == "add"
    }
}
