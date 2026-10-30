import Testing
import Foundation
@testable import BPLog

struct WidgetBridgeTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func r(_ sys: Int, _ dia: Int, daysAgo: Double, hours: Double = 0) -> ReadingValue {
        ReadingValue(date: now.addingTimeInterval(-(daysAgo * 86_400 + hours * 3600)), systolic: sys, diastolic: dia, pulse: 70)
    }

    @Test func emptyHasNoSnapshot() {
        #expect(WidgetBridge.snapshot([], now: now, calendar: calendar) == nil)
    }

    @Test func latestReadingAndItsCategory() throws {
        let s = try #require(WidgetBridge.snapshot([r(118, 76, daysAgo: 2), r(135, 85, daysAgo: 0, hours: 1)], now: now, calendar: calendar))
        #expect(s.systolic == 135 && s.diastolic == 85 && s.pulse == 70)
        #expect(s.categoryRaw == BPCategory.stage1.rawValue)
        #expect(s.categoryTitle == "High · Stage 1")
    }

    @Test func weekAverageCountsEachDayOnceAndIgnoresOlderReadings() throws {
        let readings = (0..<4).map { r(150, 95, daysAgo: 1, hours: Double($0)) }  // one busy day
            + [r(110, 75, daysAgo: 2), r(200, 110, daysAgo: 10)]  // a quiet day, and one outside the week
        let s = try #require(WidgetBridge.snapshot(readings, now: now, calendar: calendar))
        #expect(s.weekSystolic == 130)
        #expect(s.weekDiastolic == 85)
    }

    @Test func snapshotSurvivesJSON() throws {
        let s = try #require(WidgetBridge.snapshot([r(120, 80, daysAgo: 0)], now: now, calendar: calendar))
        #expect(try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(s)) == s)
    }

    @Test func addLink() {
        #expect(WidgetBridge.isAddLink(URL(string: "simplybp://add")!))
        #expect(!WidgetBridge.isAddLink(URL(string: "simplybp://home")!))
        #expect(!WidgetBridge.isAddLink(URL(string: "https://add")!))
    }
}
