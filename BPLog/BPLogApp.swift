import SwiftUI
import SwiftData

@main
struct BPLogApp: App {
    @State private var settings = AppSettings()
    @State private var purchases = PurchaseService()
    @Environment(\.scenePhase) private var scenePhase

    /// Local only: no iCloud for health data in v1 (guideline 5.1.3).
    private let container: ModelContainer = {
        let config = ModelConfiguration(cloudKitDatabase: .none)
        return try! ModelContainer(for: Reading.self, configurations: config)
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasCompletedOnboarding {
                    MainTabView()
                        .sheet(isPresented: introPaywall) { PaywallView() }
                } else {
                    OnboardingView()
                }
            }
                .environment(settings)
                .environment(purchases)
                .tint(AppColors.accent)
                .onChange(of: scenePhase) { _, phase in
                    // Picks up readings a smart cuff wrote to Health while we were away.
                    guard phase == .active, settings.healthEnabled else { return }
                    Task { await HealthService.importNew(into: container.mainContext) }
                }
        }
        .modelContainer(container)
    }

    /// Offered once, right after onboarding; dismissing it marks it seen.
    private var introPaywall: Binding<Bool> {
        Binding(
            get: { !settings.hasSeenIntroPaywall && !purchases.isPro },
            set: { if !$0 { settings.hasSeenIntroPaywall = true } }
        )
    }
}
