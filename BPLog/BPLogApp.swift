import SwiftUI
import SwiftData

@main
struct BPLogApp: App {
    @State private var settings: AppSettings
    @State private var purchases = PurchaseService()
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer
    /// The store on disk couldn't be opened; the app runs on an empty in-memory one and says so.
    @State private var storeFailed = false

    init() {
        let settings = AppSettings(defaults: LaunchMode.isThrowaway ? UserDefaults(suiteName: "uitest-\(UUID().uuidString)")! : .standard)
        if LaunchMode.skipOnboarding {
            settings.hasCompletedOnboarding = true
            settings.hasSeenIntroPaywall = true
        }
        if LaunchMode.isThrowaway { ReviewService.prompt = {} }
        Analytics.configure(enabled: settings.analyticsEnabled)
        _settings = State(initialValue: settings)
        // Local only: no iCloud for health data in v1 (guideline 5.1.3).
        let config = ModelConfiguration(isStoredInMemoryOnly: LaunchMode.isThrowaway, cloudKitDatabase: .none)
        if let opened = try? ModelContainer(for: Reading.self, configurations: config) {
            container = opened
        } else {
            // Better than a crash on every launch: the file stays untouched for a later fix or support.
            container = try! ModelContainer(for: Reading.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            _storeFailed = State(initialValue: true)
        }
        if LaunchMode.isDemo {
            for s in DemoData.samples(now: Date(), calendar: .current) {
                container.mainContext.insert(Reading(date: s.value.date, systolic: s.value.systolic, diastolic: s.value.diastolic,
                                                     pulse: s.value.pulse, tags: s.tags))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasCompletedOnboarding {
                    MainTabView()
                        .sheet(isPresented: introPaywall) { PaywallView(source: "intro") }
                } else {
                    OnboardingView()
                }
            }
                .environment(settings)
                .environment(purchases)
                .tint(AppColors.accent)
                .alert("Your readings couldn't be opened", isPresented: $storeFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Nothing has been deleted. Please restart Simply BP. If this keeps happening, contact support from Settings.")
                }
                .onOpenURL { url in
                    if WidgetBridge.isAddLink(url) { settings.pendingAddReading = true }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Picks up readings a smart cuff wrote to Health while we were away.
                    guard phase == .active, settings.healthEnabled else { return }
                    Task { await HealthService.importNew(into: container.mainContext, deletedIDs: settings.deletedIDs) }
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
