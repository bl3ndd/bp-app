# BP Log

iOS blood pressure diary. SwiftUI, SwiftData, Swift Charts, HealthKit, StoreKit 2. No third-party packages. iOS 18+.

Docs: `SPEC.md` (what the app does), `PLAN.md` (implementation plan), `ASO.md` (App Store metadata and review notes), `PRIVACY.md` (privacy policy draft).

## Run

Open `BPLog.xcodeproj`, scheme **BPLog**, run on a device.

- **StoreKit:** Product › Scheme › Edit Scheme › Run › Options › StoreKit Configuration › `BPLog.storekit`, so the Pro purchase works without App Store Connect.
- **HealthKit:** turn on Settings › Apple Health in the app. To simulate a smart cuff, add a blood pressure sample in the Health app, then reopen BP Log.

Launch arguments (Debug only):

| Argument | Effect |
|---|---|
| `-FREE` | Treat as not Pro, even if the sandbox owns the purchase |
| `-SNAPSHOT…` | Treat as Pro and suppress the review prompt (screenshots) |

## Test

Unit tests (Swift Testing) run on the connected iPhone over USB:

```bash
xcodebuild test -project BPLog.xcodeproj -scheme BPLog \
  -destination 'id=<device UDID>' -only-testing:BPLogTests -allowProvisioningUpdates
```

Covered: categories and input limits, every `StatsEngine` function including daily averaging, Health metadata/import/dedup, JSON backup round trip, Pro gating and range intervals, PDF content and pagination, reminder requests, review prompt rules.

## Before submission

See `PLAN.md` › Task 11 compliance checklist. Placeholders to replace:

- `AppLinks.privacyPolicy` and `AppLinks.support` (`BPLog/Models/AppLinks.swift`)
- Create the IAP `white.tea.BPLog.pro` ($14.99, non-consumable) in App Store Connect
- Host `PRIVACY.md` and fill in the contact address
