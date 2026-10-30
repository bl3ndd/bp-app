import Testing
import Foundation
@testable import BPLog

struct DemoDataTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    @Test func plausibleAndDeterministic() {
        let a = DemoData.samples(now: now, calendar: calendar)
        #expect(a == DemoData.samples(now: now, calendar: calendar))
        #expect(a.count > 60)
        #expect(a.allSatisfy { ReadingLimits.isValid(systolic: $0.value.systolic, diastolic: $0.value.diastolic, pulse: $0.value.pulse) })
        #expect(a.allSatisfy { $0.value.date <= now })
    }

    @Test func coversSeveralCategoriesAndImproves() {
        let a = DemoData.samples(now: now, calendar: calendar)
        let days = StatsEngine.daily(a.map(\.value), calendar: calendar)
        #expect(Set(days.map(\.category)).count >= 3)
        #expect(StatsEngine.trend(days)!.systolicPerWeek < 0)
    }
}
