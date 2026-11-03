import Foundation
import Observation

/// Someone else whose readings this phone keeps: a partner, a parent (Pro).
/// The owner isn't in the list; their readings carry no person.
nonisolated struct Person: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID()
    var name: String
}

/// User preferences backed by UserDefaults.
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }
    /// The paywall is offered once, after the first saved reading, never again unprompted.
    var hasSeenIntroPaywall: Bool { didSet { defaults.set(hasSeenIntroPaywall, forKey: Keys.introPaywall) } }
    var healthEnabled: Bool { didSet { defaults.set(healthEnabled, forKey: Keys.health) } }
    /// Anonymous usage counts (TelemetryDeck). On by default, as in Mezame; off in Settings.
    var analyticsEnabled: Bool {
        didSet {
            defaults.set(analyticsEnabled, forKey: Keys.analytics)
            Analytics.setEnabled(analyticsEnabled)
        }
    }
    /// Set by a widget's "add" link; Home opens the entry form and clears it. Not persisted.
    var pendingAddReading = false
    /// Health sample ids and reading ids the user deleted, so a Health sync never
    /// brings them back (a cuff's sample stays in Health; we just stop importing it).
    private(set) var deletedIDs: Set<UUID> {
        didSet { defaults.set(deletedIDs.map(\.uuidString), forKey: Keys.deleted) }
    }
    /// Reminder times as minutes since midnight (480 = 08:00).
    var reminderMinutes: [Int] { didSet { defaults.set(reminderMinutes, forKey: Keys.reminders) } }
    /// "In range" means below both targets. 130/80 is the AHA treatment goal for most adults.
    var targetSystolic: Int { didSet { defaults.set(targetSystolic, forKey: Keys.targetSystolic) } }
    var targetDiastolic: Int { didSet { defaults.set(targetDiastolic, forKey: Keys.targetDiastolic) } }
    /// What the owner is called in the person switcher.
    var ownerName: String { didSet { defaults.set(ownerName, forKey: Keys.ownerName) } }
    private(set) var people: [Person] {
        didSet { defaults.set(try? JSONEncoder().encode(people), forKey: Keys.people) }
    }
    /// Whose readings the tabs show; nil is the owner.
    var activePersonID: UUID? { didSet { defaults.set(activePersonID?.uuidString, forKey: Keys.activePerson) } }

    var activeName: String { name(of: activePersonID) }

    func name(of person: UUID?) -> String {
        people.first { $0.id == person }?.name ?? ownerName
    }

    @discardableResult
    func addPerson(named name: String) -> Person {
        let person = Person(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        people.append(person)
        return person
    }

    func rename(_ person: UUID, to name: String) {
        guard let i = people.firstIndex(where: { $0.id == person }) else { return }
        people[i].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func removePerson(_ person: UUID) {
        people.removeAll { $0.id == person }
        if activePersonID == person { activePersonID = nil }
    }

    /// People from a backup that aren't here yet; existing ones keep their current names.
    func merge(_ incoming: [Person]) {
        let known = Set(people.map(\.id))
        people += incoming.filter { !known.contains($0.id) }
    }

    func rememberDeleted(_ ids: [UUID]) {
        deletedIDs.formUnion(ids)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        hasSeenIntroPaywall = defaults.bool(forKey: Keys.introPaywall)
        healthEnabled = defaults.bool(forKey: Keys.health)
        deletedIDs = Set((defaults.stringArray(forKey: Keys.deleted) ?? []).compactMap(UUID.init(uuidString:)))
        analyticsEnabled = defaults.object(forKey: Keys.analytics) as? Bool ?? true
        reminderMinutes = defaults.array(forKey: Keys.reminders) as? [Int] ?? []
        targetSystolic = defaults.object(forKey: Keys.targetSystolic) as? Int ?? 130
        targetDiastolic = defaults.object(forKey: Keys.targetDiastolic) as? Int ?? 80
        ownerName = defaults.string(forKey: Keys.ownerName) ?? "Me"
        let people = (defaults.data(forKey: Keys.people)).flatMap { try? JSONDecoder().decode([Person].self, from: $0) } ?? []
        self.people = people
        let active = defaults.string(forKey: Keys.activePerson).flatMap(UUID.init(uuidString:))
        activePersonID = people.contains { $0.id == active } ? active : nil
    }

    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let introPaywall = "hasSeenIntroPaywall"
        static let health = "healthEnabled"
        static let deleted = "deletedReadingIDs"
        static let analytics = "analyticsEnabled"
        static let reminders = "reminderMinutes"
        static let targetSystolic = "targetSystolic"
        static let targetDiastolic = "targetDiastolic"
        static let ownerName = "ownerName"
        static let people = "people"
        static let activePerson = "activePersonID"
    }
}
