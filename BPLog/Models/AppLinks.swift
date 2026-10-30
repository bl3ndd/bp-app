import Foundation

/// External links shown in the app.
/// PLACEHOLDERS: replace both before App Store submission (guideline 5.1.1(i)
/// requires a working privacy policy link in the app and in App Store Connect).
enum AppLinks {
    static let privacyPolicy = URL(string: "https://example.com/bplog/privacy")!
    static let support = URL(string: "mailto:support@example.com?subject=BP%20Log")!
}
