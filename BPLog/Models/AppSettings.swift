import Foundation
import Observation

/// User preferences backed by UserDefaults.
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }
    /// The paywall is offered once right after onboarding, never again unprompted.
    var hasSeenIntroPaywall: Bool { didSet { defaults.set(hasSeenIntroPaywall, forKey: Keys.introPaywall) } }
    var healthEnabled: Bool { didSet { defaults.set(healthEnabled, forKey: Keys.health) } }
    /// Anonymous usage counts (TelemetryDeck). On by default, as in Mezame; off in Settings.
    var analyticsEnabled: Bool {
        didSet {
            defaults.set(analyticsEnabled, forKey: Keys.analytics)
            Analytics.setEnabled(analyticsEnabled)
        }
    }
    /// Reminder times as minutes since midnight (480 = 08:00).
    var reminderMinutes: [Int] { didSet { defaults.set(reminderMinutes, forKey: Keys.reminders) } }
    /// "In range" means below both targets. 130/80 is the AHA treatment goal for most adults.
    var targetSystolic: Int { didSet { defaults.set(targetSystolic, forKey: Keys.targetSystolic) } }
    var targetDiastolic: Int { didSet { defaults.set(targetDiastolic, forKey: Keys.targetDiastolic) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        hasSeenIntroPaywall = defaults.bool(forKey: Keys.introPaywall)
        healthEnabled = defaults.bool(forKey: Keys.health)
        analyticsEnabled = defaults.object(forKey: Keys.analytics) as? Bool ?? true
        reminderMinutes = defaults.array(forKey: Keys.reminders) as? [Int] ?? []
        targetSystolic = defaults.object(forKey: Keys.targetSystolic) as? Int ?? 130
        targetDiastolic = defaults.object(forKey: Keys.targetDiastolic) as? Int ?? 80
    }

    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let introPaywall = "hasSeenIntroPaywall"
        static let health = "healthEnabled"
        static let analytics = "analyticsEnabled"
        static let reminders = "reminderMinutes"
        static let targetSystolic = "targetSystolic"
        static let targetDiastolic = "targetDiastolic"
    }
}
