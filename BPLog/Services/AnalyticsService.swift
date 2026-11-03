import Foundation
import TelemetryDeck

/// Feature-usage counting only, via TelemetryDeck (anonymized, no user IDs).
/// Every signal is an event name plus at most a flag-like parameter
/// ("from": "charts"). NOTHING health-related ever goes through here: no
/// readings, categories, pulse, tags, notes or Health data — guidelines
/// 5.1.2(vi) and 5.1.3(i) forbid sharing it with third parties. Keep it that way.
///
/// Sends nothing while the user has "Share anonymous usage stats" off, during
/// UI tests or `-SNAPSHOT` runs. DEBUG builds are flagged as test signals by the SDK.
enum Analytics {
    /// TelemetryDeck App ID. Public UUID, not a secret.
    static let appID = "23B18CBB-2859-4084-A182-F5097B548D02"
    /// The org namespace: signals sent without it never reach the dashboard.
    static let namespace = "com.whitteam"

    enum Event: String {
        case onboardingStep = "onboarding.step"
        /// `health`, `reminders` = "on" | "off".
        case onboardingCompleted = "onboarding.completed"
        case readingAdded = "reading.added"
        case readingEdited = "reading.edited"
        case readingDeleted = "reading.deleted"
        /// `from` = first_reading | charts | stats | report.
        case paywallShown = "paywall.shown"
        case proPurchased = "pro.purchased"
        case proRestored = "pro.restored"
        case statsOpened = "stats.opened"
        case reportCreated = "report.created"
        case healthEnabled = "health.enabled"
        case healthSynced = "health.synced"
        case backupSaved = "backup.saved"
        case backupRestored = "backup.restored"
        case remindersChanged = "reminders.changed"
        case personAdded = "person.added"
    }

    /// Where events go. Replaced by tests with a recording closure.
    static var sink: (String, [String: String]) -> Void = { name, params in
        TelemetryDeck.signal(name, parameters: params)
    }

    private(set) static var isEnabled = true
    private static var config: TelemetryDeck.Config?

    private static var isSuppressed: Bool {
        LaunchMode.isThrowaway || ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-SNAPSHOT") }
    }

    /// Call once at launch, before any view appears.
    static func configure(enabled: Bool) {
        isEnabled = enabled
        guard !isSuppressed else { return }
        let config = TelemetryDeck.Config(appID: appID, namespace: namespace)
        config.analyticsDisabled = !enabled
        self.config = config
        TelemetryDeck.initialize(config: config)
    }

    /// Flips our gate and the SDK's own switch, so its automatic session signal stops too.
    static func setEnabled(_ on: Bool) {
        isEnabled = on
        config?.analyticsDisabled = !on
    }

    static func track(_ event: Event, _ params: [String: String] = [:]) {
        guard isEnabled, !isSuppressed else { return }
        sink(event.rawValue, params)
    }
}
