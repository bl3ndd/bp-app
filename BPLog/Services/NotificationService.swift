import UserNotifications

/// Daily reminders to take a reading. Morning and evening are the times home
/// monitoring guidance asks for; the user picks the exact times.
enum NotificationService {
    nonisolated static let idPrefix = "reading-reminder-"
    static let defaultMorning = 8 * 60
    static let defaultEvening = 20 * 60

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces every pending reminder with one per time in `minutes`.
    /// Reminders are the only notifications this app schedules.
    static func schedule(minutes: [Int]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        requests(minutes: minutes).forEach { center.add($0) }
    }

    // MARK: Request builders (pure, unit-tested)

    nonisolated static func requests(minutes: [Int]) -> [UNNotificationRequest] {
        Set(minutes).sorted().map { m in
            let content = UNMutableNotificationContent()
            content.title = "BP Log"
            content.body = m < 12 * 60
                ? "Good morning! Time to check your blood pressure."
                : "Evening check: time to take your blood pressure."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: m / 60, minute: m % 60), repeats: true)
            return UNNotificationRequest(identifier: "\(idPrefix)\(m)", content: content, trigger: trigger)
        }
    }
}
