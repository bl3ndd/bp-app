import Foundation

/// Launch arguments for UI tests (Debug builds only; Release ignores them).
/// `-UITEST`: in-memory store and throwaway settings, so tests never touch real
/// readings and each run starts clean. `-SKIP_ONBOARDING`: start on Home.
/// Pro state comes from `PurchaseService`'s `-FREE` / `-SNAPSHOT`.
enum LaunchMode {
    #if DEBUG
    static let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST")
    static let skipOnboarding = ProcessInfo.processInfo.arguments.contains("-SKIP_ONBOARDING")
    #else
    static let isUITest = false
    static let skipOnboarding = false
    #endif
}
