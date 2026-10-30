import StoreKit
import UIKit

/// Asks for an App Store rating once the app has proven useful — five saved
/// readings — and at most once per version. Never right after a crisis-range
/// reading: that's a moment for the doctor, not for a rating prompt.
enum ReviewService {
    /// Swappable for tests, which must not touch the real counters or show a prompt.
    static var defaults: UserDefaults = .standard
    static var prompt: () -> Void = { promptAfterDismissal() }

    static let threshold = 5
    private static let countKey = "savedReadingCount"
    private static let promptedVersionKey = "reviewPromptedVersion"

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Screenshot runs drive real flows; a system rating alert must never land in one.
    private static var isSnapshot: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-SNAPSHOT") }
    }

    /// Call when a new reading is saved (not on edits).
    static func recordReading(_ category: BPCategory) {
        guard !isSnapshot else { return }
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)
        guard count >= threshold, category != .crisis,
              defaults.string(forKey: promptedVersionKey) != currentVersion else { return }
        defaults.set(currentVersion, forKey: promptedVersionKey)
        prompt()
    }

    /// The entry form is a sheet dismissing as this fires; asking mid-transition
    /// gets the alert dropped, so wait for the scene to settle.
    private static func promptAfterDismissal() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
