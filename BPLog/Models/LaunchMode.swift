import Foundation

/// Launch arguments for UI tests and demos (Debug builds only; Release ignores them).
/// `-UITEST`: in-memory store and throwaway settings, so tests never touch real
/// readings and each run starts clean. `-SKIP_ONBOARDING`: start on Home.
/// `-DEMO`: like `-UITEST`, plus two months of sample readings and no onboarding,
/// for trying statistics and the purchase flow on a device.
/// Pro state comes from `PurchaseService`'s `-FREE` / `-SNAPSHOT`.
enum LaunchMode {
    #if DEBUG
    static let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST")
    static let isDemo = ProcessInfo.processInfo.arguments.contains("-DEMO")
    static let skipOnboarding = isDemo || ProcessInfo.processInfo.arguments.contains("-SKIP_ONBOARDING")
    #else
    static let isUITest = false
    static let isDemo = false
    static let skipOnboarding = false
    #endif

    /// Nothing from this run may reach the real store, Health, the widget or analytics.
    static var isThrowaway: Bool { isUITest || isDemo }
}
