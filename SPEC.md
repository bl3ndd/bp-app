# Simply BP — product spec (v1)

A blood pressure diary for US adults 50+: type readings from a home monitor, see categories, daily averages and trends, share a doctor report. Niche research and rationale: `PLAN.md` (Overview) and `ASO.md`.

## Free vs Pro

| Free | Pro ($14.99 one-time, `white.tea.BPLog.pro`) |
|---|---|
| Unlimited logging, edit, delete | Doctor PDF report |
| History with daily averages | Full statistics screen |
| Home: latest reading, today's and 7-day averages | Charts for 90D / 1Y / All |
| Charts 7D / 30D | |
| Apple Health sync | |
| JSON backup / restore | |
| Reminders | |

Gating goes through one predicate, `ProFeature.isLocked(_:isPro:)`. The paywall shows when a locked feature is tapped, plus once right after onboarding. No subscription, no ads, no account.

## Categories (`BPCategory.classify`)

2017 ACC/AHA. Systolic and diastolic are graded separately and the higher grade wins.

| Category | Systolic | | Diastolic |
|---|---|---|---|
| Normal | < 120 | and | < 80 |
| Elevated | 120–129 | and | < 80 |
| High · Stage 1 | 130–139 | or | 80–89 |
| High · Stage 2 | ≥ 140 | or | ≥ 90 |
| Hypertensive crisis | > 180 | and/or | > 120 |
| Low (not an AHA category) | < 90 | or | < 60, only when nothing is high |

Input limits (`ReadingLimits`): SYS 60–260, DIA 30–160, pulse 30–220, SYS > DIA. Each error has its own message.

## Several readings a day

`StatsEngine.daily` collapses each calendar day into one reading of the day's rounded averages. Averages, period comparison, trend, category and target-range shares, weekday averages, pulse pressure and MAP use daily values, so each day counts once. Highest/lowest and morning vs. evening use the raw readings. Charts default to one point per day.

## Data

- SwiftData, local only. No iCloud/CloudKit: guideline 5.1.3(ii) "may not store personal health information in iCloud".
- Apple Health (opt-in): writes BP correlations + heart rate with metadata (reading id, arm, position, tags, note, `WasUserEntered`). Reads every source. Our own writes come back on a fresh install, which is how a new phone gets its history. Dedup is by Health sample id and by our reading id.
- Analytics: TelemetryDeck (`AnalyticsService.swift`), anonymous feature-usage events only, never health data; on by default, off in Settings › Privacy. Suppressed in UI tests and `-SNAPSHOT` runs.
- JSON backup (free): user-initiated export to a user-chosen location; restore is additive (matched on reading id).

## Out of scope for v1

CSV export (dropped: PDF serves the doctor, backup and Health serve portability), iCloud sync, Bluetooth cuffs, medication reminders, blood sugar, widgets, Watch app, localization beyond English, any measuring or diagnosis.
