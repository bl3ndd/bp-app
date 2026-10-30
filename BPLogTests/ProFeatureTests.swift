import Testing
import Foundation
@testable import BPLog

struct ProFeatureTests {
    @Test(arguments: [ProFeature.pdfReport, .fullStats, .longChartRanges])
    func lockedOnlyWithoutPro(feature: ProFeature) {
        #expect(ProFeature.isLocked(feature, isPro: false))
        #expect(!ProFeature.isLocked(feature, isPro: true))
    }

    @Test func rangeIntervals() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let week = ChartRange.week.interval(now: now)!
        #expect(week.end == now)
        #expect(week.duration == 7 * 86_400)
        let previous = ChartRange.week.previousInterval(now: now)!
        #expect(previous.end == week.start)
        #expect(previous.duration == week.duration)
        #expect(ChartRange.all.interval(now: now) == nil)
        #expect(ChartRange.all.previousInterval(now: now) == nil)
    }

    @Test func shortChartRangesAreFree() {
        #expect(ChartRange.week.feature == nil)
        #expect(ChartRange.month.feature == nil)
        #expect(ChartRange.quarter.feature == .longChartRanges)
        #expect(ChartRange.year.feature == .longChartRanges)
        #expect(ChartRange.all.feature == .longChartRanges)
    }
}

@MainActor
@Suite(.serialized)
struct AnalyticsTests {
    @Test func sendsOnlyWhileEnabled() {
        var sent: [String] = []
        let saved = Analytics.sink
        Analytics.sink = { name, _ in sent.append(name) }
        defer { Analytics.sink = saved; Analytics.setEnabled(true) }
        Analytics.setEnabled(true)
        Analytics.track(.readingAdded)
        Analytics.setEnabled(false)
        Analytics.track(.reportCreated)
        #expect(sent == ["reading.added"])
    }
}
