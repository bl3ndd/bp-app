# App Store metadata (US, en-US)

Built from the niche research in `~/Documents/projects/aso-keywords` (Oct 2026, Apple Ads popularity 5–100 + iTunes top-10 checks).

## Why this name

With near-zero ratings, our apps rank high only for the exact phrase in their title: Mezame is #1 for "cbt thought journal" (its title) and #4 for "cbt journal", and uDoctor sits at #2 for `blood pressure log` with 4 ratings. So the title carries the exact top phrase.

| Keyword | Popularity | Top-5 median ratings | Note |
|---|---|---|---|
| blood pressure | 56 | 32.8k | the head term; bonus if we grow |
| blood pressure log | 53 | 8.8k | **primary target**, newcomers rank top-5 |
| blood pressure monitor | 51 | 5k | top-1 is a fake "finger" app; intent partly "measure with phone" |
| blood pressure tracker | 24 | 8.8k | |
| bp log | 23 | 8.8k | |
| pill / medication reminder | 49 / 39 | 9.9k | not a v1 feature, don't target (2.3.7) |

Searchers phrase it as "blood pressure", rarely "BP" alone; apps from the top of Apple's suggestions are "… free" variants.

## Metadata

- **Support URL:** `https://bp-app-site.vercel.app/support.html`
- **Privacy Policy URL:** `https://bp-app-site.vercel.app/privacy.html`
- **Marketing URL (optional):** `https://bp-app-site.vercel.app/`

- **Name (29/30):** `Simply BP: Blood Pressure Log` — brand "Simply BP" checked free in the US App Store on 2026-10-30 (0 apps with the word); it states our promise (simple, vs. SmartBP's paywall-everywhere complaints) and adds "BP" for bp log / bp tracker searches. A brand before the phrase doesn't hurt ranking: "Mezame — CBT Thought Journal" is #1 for its phrase.
- **Subtitle (28/30):** `Tracker, Charts & Doctor PDF`
- **Keywords (85/100), no repeats of name/subtitle words:**
  `monitor,pulse,heart,rate,high,health,diary,vitals,check,cardio,heartbeat,bpm,wellness`
  Chosen from two popularity runs on 2026-10-30 (`aso-keywords/results_keywords_meta*_us.csv`): live words only — monitor (bp monitor 45, blood pressure monitor 51), pulse 60, heart rate 50, health (tracker) 42, high (blood pressure) 35, diary (bp diary 19), vitals 40, check (blood pressure check 23), cardio 43, heartbeat 46, bpm 43, wellness 44. Dropped as dead (popularity 5): hypertension, journal, record, readings, chart, low, systolic, diastolic, cuff, average, report, history, hypotension.
- **Primary category:** Health & Fitness (not Medical). **Secondary:** Medical.
- **Age rating:** answer honestly; medical/treatment information = "infrequent/mild" at most.

Don't use: "AHA" / "American Heart Association" in the name, subtitle or keywords (trademark, 2.3.7 / 5.2.1; citing the guideline in the description is fine), "measure" / "monitor" in name or subtitle (1.4.1: we don't measure), prices in name/subtitle/screenshots (2.3.7). "No subscription" is a pricing-model claim, so keep it in the description and promo text, and check how App Review treats it in screenshots.

## Promotional text (170)

Log your blood pressure in seconds, see daily averages and trends, and bring a clean report to your doctor. One-time Pro unlock — no subscription, no ads.

## Description

Keep a simple, reliable record of your blood pressure — and know what your numbers are doing.

Simply BP is a blood pressure diary for the readings you take with your own home monitor. Add a reading in seconds, see it colored by the standard blood pressure categories, and watch your daily averages and trends over time.

WHAT YOU GET FREE
• Fast entry: top number, bottom number and pulse, with arm, position, tags and notes
• Categories from the 2017 ACC/AHA guideline, plus a "Low" flag below 90/60
• History with daily averages when you take several readings a day, plus search and a filter by day or month
• 7- and 30-day charts
• Apple Health: readings you add are saved to Health, and readings from a smart monitor show up here automatically. Apple Health keeps your history in sync across your devices.
• Morning and evening reminders
• Home Screen and Lock Screen widgets: your latest reading, and one tap to add a new one
• Backup to a file you keep, and restore any time

BP LOG PRO — ONE-TIME PURCHASE
• Doctor-ready PDF report: summary, chart and every reading, on US Letter paper
• Full statistics: trend per week, morning vs. evening, days in your target range, by day of week, pulse pressure and more
• Charts for 90 days, a year, or all time

No subscription. No ads. No account. Your readings stay on your devices and in Apple Health — we never see them.

Simply BP is not a medical device and does not measure blood pressure. Always talk to your doctor before making medical decisions.

## Screenshot captions (draft, design pass later)

1. Your blood pressure, logged in seconds
2. Daily averages, even with several readings a day
3. See your trend at a glance
4. A report your doctor can read
5. Syncs with Apple Health
6. One-time unlock. No subscription. No ads.

## App Privacy answers (App Store Connect)

With TelemetryDeck the answer is no longer "Data Not Collected". Declare: **Usage Data › Product Interaction**, *Not linked to the user*, *Not used for tracking*, purpose *Analytics* — the same as `BPLog/PrivacyInfo.xcprivacy` and Mezame's accepted setup. Check TelemetryDeck's own App Store privacy guide before submitting. Health & Fitness data: **not collected** (it never leaves the device).

## Notes for Review (2.3.1(a))

Simply BP is a blood pressure diary. It does not measure blood pressure with device sensors; users type readings from their own home monitor.

A short screen recording of the main flow is attached to this submission.

How to review: complete the 4-step onboarding (the target, Apple Health and reminders can be skipped). On Home tap "Add Reading", enter e.g. 128 / 82 / 70 and Save. Add a few more readings to see History, Charts and Stats populate.

- HealthKit: reads and writes blood pressure (systolic/diastolic correlation) and heart rate, only after the user turns on Settings › Apple Health. Samples we write are marked HKMetadataKeyWasUserEntered. Health data is never sent anywhere. The only network traffic is anonymous feature-usage counts via TelemetryDeck (event names only, no health data; opt-out in Settings › Privacy); no ads.
- Storage: local SwiftData store only. No iCloud/CloudKit (5.1.3(ii)). The JSON backup is created only when the user taps "Back Up Readings" and is saved wherever the user chooses with the system file picker.
- In-App Purchase: one non-consumable, "Simply BP Pro" (`white.tea.BPLog.pro`), $14.99. It unlocks the doctor PDF report (Home or Stats › Doctor Report), full statistics (Stats tab), and 90D/1Y/All chart ranges. Restore Purchases is in the paywall and in Settings. Pro features don't require HealthKit access.
- Medical: categories follow the 2017 ACC/AHA guideline; "Low" (below 90/60) is a separate, commonly used threshold. The app reminds users to consult a doctor in onboarding, in Settings › About and on every report page; crisis-range readings show a banner pointing to their doctor or 911 / local emergency number. No diagnosis or treatment advice.
