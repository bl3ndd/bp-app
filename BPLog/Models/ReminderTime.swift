import Foundation

/// Reminder times are stored as minutes since midnight; pickers want a `Date`.
nonisolated enum ReminderTime {
    static func date(fromMinutes minutes: Int, calendar: Calendar = .current, on day: Date = Date()) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: calendar.startOfDay(for: day)) ?? day
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Before noon counts as the morning slot, the rest as evening.
    static func isMorning(_ minutes: Int) -> Bool { minutes < 12 * 60 }
}
