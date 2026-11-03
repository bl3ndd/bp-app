# BP Log — MVP plan (one weekend)

## Status

2026-10-30: Tasks 1–9 done (49 unit tests green on device). Task 10 manual checks moved to the UI-testing phase. Task 11 docs written (README, SPEC, ASO, PRIVACY draft); compliance items and placeholders remain. Next: UI tests + manual pass with the user, then the design pass (custom Home/entry/paywall/stats, icon, screenshots).

## Overview

A simple, honest blood pressure diary for iOS aimed at US adults 50+. Niche research (Oct 2026, `~/Documents/projects/aso-keywords`) showed: the blood pressure keyword cluster has real demand (`blood pressure` 56, `blood pressure log` 53, `blood pressure monitor` 51), about 10 apps of the cluster sit in the US top-100 grossing Medical chart (SmartBP at #14), and newcomers reach the top 10 for `log`/`tracker` keywords. The leader SmartBP has 31% 1★ in its last 500 reviews. The complaints: a paywall on every screen that overwhelms elderly users, $10/month, Apple Health sync bugs, ads. Our angle: fast entry, reliable Apple Health sync, rich statistics, a doctor PDF, **no subscription, no ads**, a single one-time Pro purchase.

Free download. Free tier: unlimited logging, Apple Health read/write, history, basic 30-day chart, JSON backup, reminders. (CSV export was dropped on 2026-10-30: PDF covers the doctor, JSON backup and Apple Health cover portability.) Pro ($14.99 non-consumable): doctor PDF report and the full statistics screen. As in Mezame: the user's data is free, the insights are paid.

**Out of scope (why):**
- iCloud sync: guideline 5.1.3 restricts storing personal health info in iCloud; recheck the current text before adding it.
- Bluetooth cuff pairing: per-vendor protocols. Smart cuffs already write to Apple Health, which we read.
- Medication/pill reminders (`pill reminder` pop 49): good v1.1 candidate, not a weekend job.
- Blood sugar logging: v2 (same mechanics, separate keyword cluster).
- Widgets, Apple Watch app, localization beyond English: after the US launch proves traction. DE/JP are the first localization candidates.
- Any "measuring" (camera/finger) or diagnosis/advice: review risk (guideline 1.4.1) and FDA territory. We display readings and the standard AHA category table, nothing more.
- Ads SDKs: none. Analytics: TelemetryDeck added on 2026-10-30 at the user's request, feature-usage event names only; health data never leaves the device (FTC, guidelines 5.1.2(vi) and 5.1.3).

## Context

- **Files involved** (new project, created in Xcode GUI as `BPLog` in `~/Documents/projects/bp-log`):
  - `BPLog/BPLogApp.swift` — app entry, SwiftData container (local only), injects `PurchaseService`, routes to onboarding
  - `BPLog/Models/Reading.swift` — `@Model Reading`: `id`, `date`, `systolic`, `diastolic`, `pulse?`, `arm`, `position`, `tags`, `note`, `source` (`.manual`/`.health`), `healthKitID: UUID?`
  - `BPLog/Models/BPCategory.swift` — AHA 2017 categories + `classify(systolic:diastolic:)`
  - `BPLog/Models/AppSettings.swift` — onboarding flag, reminder times, Health enabled, unit prefs (UserDefaults, `@Observable`)
  - `BPLog/Services/StatsEngine.swift` — pure statistics over `[ReadingValue]`
  - `BPLog/Services/HealthService.swift` — HealthKit blood pressure correlation + heart rate read/write, import with dedup
  - `BPLog/Services/PurchaseService.swift` — copied from Mezame, new `productID`
  - `BPLog/Services/PDFGenerator.swift` — doctor report, built on Mezame's `UIGraphicsPDFRenderer` helpers
  - `BPLog/Services/NotificationService.swift` — morning/evening reminders, adapted from Mezame
  - `BPLog/Services/ReviewService.swift` — copied from Mezame (prompts once per version after N readings)
  - `BPLog/Theme/DesignTokens.swift` — copied from Mezame, new accent; large type defaults for 50+
  - `BPLog/Views/Onboarding/OnboardingView.swift` — 3 steps: value + disclaimer, Health permission, reminder time
  - `BPLog/Views/Home/HomeView.swift` — last reading card with category, 7-day averages, big "Add reading" button
  - `BPLog/Views/Entry/AddReadingView.swift` — number wheels/keypad for SYS/DIA/pulse, arm, position, tags, note
  - `BPLog/Views/History/HistoryView.swift` — list grouped by day, swipe to delete, edit
  - `BPLog/Views/Charts/ChartView.swift` — Swift Charts SYS/DIA/pulse with category bands, 30 days free / any range Pro
  - `BPLog/Views/Stats/StatsView.swift` — Pro statistics screen
  - `BPLog/Views/Export/ReportView.swift` — doctor PDF report (Pro) with date range
  - `BPLog/Views/Paywall/PaywallView.swift` — adapted from Mezame's `Views/Insights/PaywallView.swift`
  - `BPLog/Views/Settings/SettingsView.swift` — reminders, Health toggle, restore purchases, disclaimer, privacy, contact
  - `BPLog/Views/Components/` — copy `CardView.swift`, `ProMark.swift` from Mezame
  - `BPLog/BPLog.storekit` — local StoreKit config with the Pro product
  - `BPLog/BPLog.entitlements` — HealthKit
  - `BPLogTests/*.swift` — Swift Testing suites per task
- **Related patterns (from Mezame, `~/Documents/projects/kpt-diary/kpt-diary`):**
  - `Services/PurchaseService.swift` — `@Observable` StoreKit 2 single non-consumable, `Transaction.updates` listener, `-FREE` / `-SNAPSHOT` debug args, `restore()` via `AppStore.sync()`
  - `Services/HealthService.swift` — stateless `enum` service over a static `HKHealthStore`, pure helpers kept separately testable (`valence`, `mergedHours`)
  - `Services/PDFGenerator.swift` — `enum` with A4 renderer, local `draw/checkBreak/separator` helpers, unique temp folder per export
  - `Services/NotificationService.swift` — request builders split from scheduling so they're testable
  - `kpt_diaryApp.swift` — container creation with a fallback, environment injection
  - Tests: Swift Testing (`import Testing`, `@Test`, `#expect`), e.g. `kpt-diaryTests/HealthServiceTests.swift`
- **Dependencies:** SwiftUI, SwiftData, Swift Charts, HealthKit, StoreKit 2, UserNotifications, UIKit PDF. No third-party packages. iOS 18.0 deployment target (same as Mezame). Configured later by the user: App Store Connect app record, IAP product, HealthKit capability on the App ID, privacy policy URL.

## Development Approach

- **Testing approach:** Regular (code first, then tests), Swift Testing, as in Mezame. The project starts with the test target from the Xcode template.
- **Testable (pure, deterministic):** `BPCategory.classify`, everything in `StatsEngine`, HealthKit ↔ `ReadingValue` mapping and dedup, backup round trip, PDF generation produces a non-empty multi-section file, notification request builders, the paywall gating predicate.
- **Validated by self-launch only:** HealthKit authorization and real reads/writes (needs a device or a simulator with Health data), StoreKit purchase/restore (against `BPLog.storekit`), PDF visual layout, the onboarding flow.
- **Placeholders the user wires up:**
  - Bundle ID: `com.<name>.bplog` (final name TBD)
  - Product ID: `com.<name>.bplog.pro`, non-consumable, $14.99
  - Privacy policy and support URLs
  - App name and subtitle (see Task 11)

## Implementation Steps

### Task 1: Create the project (user, Xcode GUI)

Files:
• Create: `~/Documents/projects/bp-log/BPLog.xcodeproj` (Xcode → App, SwiftUI, Swift Testing, storage: None, "Create Git repository")

[x] Create the iOS App project `BPLog` in `~/Documents/projects/bp-log`, interface SwiftUI, testing system Swift Testing
[x] Set the deployment target to iOS 18.0 and the bundle ID placeholder
[x] Add the HealthKit capability (creates `BPLog.entitlements`), add `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` to Info
[x] Build and run the empty app in the simulator

### Task 2: Data model and AHA categories

Files:
• Create: `BPLog/Models/Reading.swift`
• Create: `BPLog/Models/BPCategory.swift`
• Create: `BPLog/Models/AppSettings.swift`
• Create: `BPLogTests/BPCategoryTests.swift`

[x] `@Model final class Reading` with the fields listed in Context; all properties defaulted; `enum Arm { left, right }`, `enum Position { sitting, standing, lying }`, `enum Source { manual, health }` stored as raw strings
[x] `struct ReadingValue` (date, systolic, diastolic, pulse): a plain value snapshot that `StatsEngine` and `PDFGenerator` take, so they are testable without SwiftData
[x] `enum BPCategory { normal, elevated, stage1, stage2, crisis }` + `static func classify(systolic:diastolic:)` per the AHA 2017 table (normal <120 and <80; elevated 120–129 and <80; stage 1 130–139 or 80–89; stage 2 ≥140 or ≥90; crisis >180 and/or >120), the higher category wins; `color`, `title`
[x] Input validation range: SYS 60–260, DIA 30–160, pulse 15–250, SYS > DIA
[x] `@Observable final class AppSettings` over UserDefaults: `hasCompletedOnboarding`, `healthEnabled`, `reminderTimes: [DateComponents]`
[x] Write tests for this task (every category boundary, "higher wins" cases like 125/85 → stage 1, crisis, validation rejects SYS ≤ DIA and out-of-range values)
[x] run project test suite — must pass before Task 3

### Task 3: Statistics engine

Files:
• Create: `BPLog/Services/StatsEngine.swift`
• Create: `BPLogTests/StatsEngineTests.swift`

[x] `enum StatsEngine` with pure functions over `[ReadingValue]` and a `DateInterval`:
  - `averages` (SYS/DIA/pulse), `min/max` with dates, `count`
  - `pulsePressure` (SYS − DIA) and `meanArterialPressure` (DIA + PP/3) averages
  - `categoryDistribution` → `[BPCategory: Int]` and share in %
  - `timeInRange` → share of readings below the user's target (default 130/80)
  - `morningVsEvening` (before 12:00 vs after 18:00) averages
  - `weekdayAverages`, `hourlyAverages`
  - `trend` → linear regression slope of SYS and DIA in mmHg per week, with a "not enough data" case (< 5 readings or < 7 days)
  - `periodComparison` → this period vs the previous one of equal length (delta SYS/DIA)
  - `streak` → consecutive days with at least one reading
  - `dailyAverages` → one point per day for charts
[x] Write tests for this task (hand-computed fixtures for each function, empty input, single reading, trend sign on rising/falling data, morning/evening split at the boundaries, streak with gaps)
[x] run project test suite — must pass before Task 4

### Task 4: Apple Health sync

Files:
• Create: `BPLog/Services/HealthService.swift`
• Create: `BPLogTests/HealthServiceTests.swift`

[x] `enum HealthService` following Mezame's shape: static `HKHealthStore`, `isAvailable`, `requestAuthorization()` for share + read of `HKCorrelationType(.bloodPressure)` (`.bloodPressureSystolic`, `.bloodPressureDiastolic`) and `.heartRate`
[x] `save(_ reading:) async -> UUID?`: writes the BP correlation (+ heart rate sample when pulse is set), returns the correlation UUID stored in `Reading.healthKitID`
[x] `delete(healthKitID:)` when a manual reading is deleted
[x] `fetchReadings(since:) async -> [HealthReading]`: reads correlations from all sources, attaches a heart rate sample within ±2 min
[x] Pure `static func newImports(_ health: [HealthReading], existingIDs: Set<UUID>) -> [HealthReading]`: skips our own writes and already imported samples
[x] `importNew(into context:)`: called on launch and on foreground when `healthEnabled`, inserts `Reading(source: .health)`
[x] Write tests for this task (dedup skips known IDs and our own writes, the pulse matching window, mmHg mapping)
[x] run project test suite — must pass before Task 5

### Task 5: Core screens — entry, home, history, chart

Files:
• Create: `BPLog/Theme/DesignTokens.swift` (copy from Mezame, new accent)
• Create: `BPLog/Views/Components/CardView.swift`, `ProMark.swift` (copy)
• Create: `BPLog/Views/Entry/AddReadingView.swift`
• Create: `BPLog/Views/Home/HomeView.swift`
• Create: `BPLog/Views/History/HistoryView.swift`
• Create: `BPLog/Views/Charts/ChartView.swift`
• Create: `BPLog/Views/MainTabView.swift`
• Modify: `BPLog/BPLogApp.swift`

[x] `BPLogApp`: local-only `ModelContainer` for `Reading`, inject `AppSettings` and `PurchaseService`, onboarding gate, Health import on `.active`
[x] `AddReadingView`: large numeric fields (SYS/DIA/pulse), date defaulting to now, arm/position pickers remembering the last choice, tag chips (`after coffee`, `stress`, `after exercise`, `medication taken`), note; shows the live `BPCategory`; on save inserts `Reading` and calls `HealthService.save` when enabled; under 10 seconds for a typical entry
[x] `HomeView`: last reading card with category color, 7-day averages, today's count, big "Add reading" button, a crisis banner ("Readings this high need medical attention. Contact your doctor or call 911 if you have symptoms") when the last reading is `crisis`
[x] `HistoryView`: grouped by day, Health-sourced rows marked with an icon, swipe to delete (also deletes from Health for our own writes), tap to edit
[x] `ChartView`: Swift Charts lines for SYS/DIA (+ pulse toggle), category bands in the background, ranges 7d/30d free; 90d/1y/all and the daily-average mode marked with `ProMark`
[x] `MainTabView`: Home, History, Charts, Stats, Settings; tab bar with large labels
[x] No unit tests here: pure UI over Tasks 2–4 logic, validated by self-launch

### Task 6: Paywall and Pro gating

Files:
• Create: `BPLog/Services/PurchaseService.swift` (copy from Mezame)
• Create: `BPLog/BPLog.storekit`
• Create: `BPLog/Views/Paywall/PaywallView.swift`
• Create: `BPLog/Models/ProFeature.swift`
• Create: `BPLogTests/ProFeatureTests.swift`

[x] Copy `PurchaseService`, set `productID = "com.<name>.bplog.pro"`, keep the `-FREE` / `-SNAPSHOT` debug arguments
[x] `BPLog.storekit` with the non-consumable at $14.99, selected in the Run scheme
[x] `enum ProFeature { pdfReport, fullStats, longChartRanges }` + `static func isLocked(_:isPro:) -> Bool`, the only gating predicate used by views
[x] `PaywallView` adapted from Mezame: headline "One price. Yours forever.", benefits (doctor PDF report, full statistics and trends, all-time charts), "No subscription. No ads." line, price from `product.displayPrice`, buy, restore, dismiss always visible
[x] Paywall appears only when tapping a locked feature, plus once after the first saved reading (dismissible). Logging, history, Health and backup are never gated
[x] Write tests for this task (`isLocked` for every feature in both states)
[x] run project test suite — must pass before Task 7

### Task 7: Pro statistics screen

Files:
• Create: `BPLog/Views/Stats/StatsView.swift`

[x] Period picker (7d / 30d / 90d / 1y / all) and cards fed by `StatsEngine`: averages with category, min/max, period-over-period delta, trend in mmHg/week with "not enough data" state, category distribution bar, time in target range, morning vs evening, weekday and hour-of-day bars, pulse pressure and MAP, streak
[x] Free users see the same screen blurred with real numbers hidden + "Unlock" (the Mezame `PaywallView` preview pattern), tapping opens the paywall
[x] No unit tests here: all math is covered in Task 3, the screen is layout only

### Task 8: Doctor PDF report (Pro)

Files:
• Create: `BPLog/Services/PDFGenerator.swift`
• Create: `BPLog/Views/Export/ReportView.swift`
• Create: `BPLogTests/ExportTests.swift`

[x] `PDFGenerator.generate(readings:range:patientName:) -> URL` on Mezame's renderer helpers: header (name optional, period, generated date), summary block (averages, min/max, category distribution, morning vs evening, trend), a chart image (render the Swift Charts view with `ImageRenderer`), the full readings table, the disclaimer footer on every page
[x] `ReportView`: date range picker, optional name, PDF button gated by `ProFeature.pdfReport`, preview and share via QuickLook
[x] Write tests for this task (PDF file exists, non-empty, page count grows with readings)
[x] run project test suite — must pass before Task 9

### Task 9: Onboarding, reminders, settings, review prompt

Files:
• Create: `BPLog/Views/Onboarding/OnboardingView.swift`
• Create: `BPLog/Services/NotificationService.swift`
• Create: `BPLog/Services/ReviewService.swift` (copy)
• Create: `BPLog/Views/Settings/SettingsView.swift`
• Create: `BPLogTests/NotificationServiceTests.swift`

[x] Onboarding: (1) value + "Not a medical device, doesn't measure blood pressure, doesn't replace your doctor" disclaimer, (2) Apple Health connect (skippable), (3) morning/evening reminder times (skippable), then the one-time paywall
[x] `NotificationService` adapted from Mezame: `reminderRequests(times:) -> [UNNotificationRequest]` builder + `schedule/cancelAll`
[x] `ReviewService`: prompt after the 5th reading, once per version, never on a crisis reading
[x] `SettingsView`: reminders, Health toggle + "Import now", target range (default 130/80), Restore purchases, disclaimer, privacy policy link, contact
[x] Write tests for this task (reminder requests: identifiers, repeat, times; review threshold logic)
[x] run project test suite — must pass before Task 10

### Task 10: Verify acceptance criteria

[ ] A reading can be added in under 10 seconds from app launch
[ ] The category is correct and shown live while typing; a crisis reading shows the banner
[ ] With Health enabled: a manual reading appears in Apple Health; a reading added in Health (simulating a smart cuff) appears in the app on next foreground, without duplicates after repeated launches
[ ] Deleting our own reading removes it from Health too
[ ] Free user: unlimited logging, history, 7d/30d charts, backup, reminders work with no paywall
[ ] Tapping the PDF, Stats or a long chart range opens the paywall; purchase in the StoreKit config unlocks all three immediately; restore works; `-FREE` shows the locked state
[ ] The PDF contains summary, chart, full table and disclaimer, and opens in QuickLook and Mail
[ ] Reminders fire at the chosen times
[ ] No network calls besides StoreKit (check with no third-party SDKs linked)
[ ] Dynamic Type at XL keeps every screen usable
[ ] Verify all new logic has unit coverage (categories, stats, Health mapping/dedup, gating, backup, PDF, notifications)

### Task 11: Update documentation and App Store metadata

Files:
• Create: `README.md`
• Create: `SPEC.md`
• Create: `ASO.md`

[x] `README.md`: build, debug arguments (`-FREE`, `-SNAPSHOT`), StoreKit config, HealthKit testing on simulator
[x] `SPEC.md`: Free vs Pro table, AHA table source, out-of-scope list from Overview
[x] App name must contain the exact phrase "Blood Pressure Log": Mezame ranks #1 only for its exact title phrase, and uDoctor sits at #2 for `blood pressure log` with 4 ratings, so exact title match is our main lever while ratings are near zero
[x] `ASO.md` from `~/Documents/projects/aso-keywords` results: target keyword portfolio (`blood pressure log`, `bp log`, `blood pressure tracker`, `blood pressure diary`, `blood pressure monitor`, `heart rate log`, `bp tracker`, `free`); title / subtitle / 100-char keywords field drafts; screenshot captions leading with "No subscription. No ads."; avoid any "measure" wording
[ ] Recheck App Review guidelines 1.4.1 and 5.1.3 against the final feature set before submission
[ ] Compliance checklist (guidelines checked verbatim, "Last Updated: October 16, 2026"):
  - 5.1.3(ii) "may not store personal health information in iCloud": no CloudKit/iCloud entitlements; backup is a user-chosen file only (done instead of iCloud sync)
  - 1.4.1: doctor reminder in onboarding and About; never claim to measure; "Low" (<90/60) is not presented as an AHA category
  - 5.1.1(i): privacy policy URL in App Store Connect AND an in-app link; list HealthKit types read/written (BP, heart rate), local-only storage, exports, how to delete
  - 2.3.7 / 5.2.1: no "AHA"/"American Heart Association" in name, subtitle or keywords
  - 2.5.1: mention Apple Health integration in the description
  - 2.3.1(a) Notes for Review: HealthKit read/write, Pro gating, PDF, JSON backup (user-initiated, user-chosen location), how to add readings in an empty app, no background monitoring
  - 2.1(b) / 3.1.1: IAP visible and functional for the reviewer, Restore Purchases visible
  - 5.1: crisis banner says "911 or your local emergency number"

## 1.1 (branch `v1.1`, not submitted; 1.0 is in review)

- **People** (Pro): Settings › People adds a partner or parent; a switcher appears at the top of every tab. `Reading.personID` (nil = owner, so 1.0 data needs no migration); people live in `AppSettings`. Only the owner's readings go to and come from Apple Health and show in the widget. The doctor report uses the person's name. Backups carry people and `personID`; 1.0 files restore as the owner's.
- Scanning a monitor's screen was tried and dropped (2026-11-03): Apple's text recognition got 9 of 55 test screens right (seven-segment digits, faint unlit segments) and often returned wrong numbers. Revisit only with a dedicated seven-segment reader.
