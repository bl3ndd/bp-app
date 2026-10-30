import Testing
import Foundation
@testable import BPLog

struct HistoryFilterTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func item(_ sys: Int, _ dia: Int, pulse: Int? = 70, tags: [String] = [], note: String = "") -> HistoryFilter.Item {
        HistoryFilter.Item(value: ReadingValue(date: Date(timeIntervalSince1970: 1_800_000_000), systolic: sys, diastolic: dia, pulse: pulse),
                           tags: tags, note: note)
    }

    @Test func numbersMatchExactly() {
        let r = item(130, 85)
        #expect(HistoryFilter.matches(r, query: "130"))
        #expect(HistoryFilter.matches(r, query: "70"))  // pulse
        #expect(!HistoryFilter.matches(r, query: "13"))
        #expect(HistoryFilter.matches(r, query: "130/85"))
    }

    @Test func categoriesTagsAndNotes() {
        let r = item(145, 92, tags: ["After coffee"], note: "Felt tired at work")
        #expect(HistoryFilter.matches(r, query: "stage 2"))
        #expect(HistoryFilter.matches(r, query: "COFFEE"))
        #expect(HistoryFilter.matches(r, query: "tired work"))
        #expect(!HistoryFilter.matches(r, query: "tired home"))
        #expect(HistoryFilter.matches(item(85, 55), query: "low"))
        #expect(HistoryFilter.matches(r, query: "  "))
    }

    @Test func monthsAndMonthFilter() {
        let d = { (m: Int, day: Int) in calendar.date(from: DateComponents(year: 2026, month: m, day: day, hour: 9))! }
        let months = HistoryFilter.months([d(10, 30), d(9, 2), d(10, 1), d(8, 15)], calendar: calendar)
        #expect(months == [d(10, 1), d(9, 1), d(8, 1)].map { calendar.dateInterval(of: .month, for: $0)!.start })
        #expect(HistoryFilter.isIn(.month(months[0]), d(10, 30), calendar: calendar))
        #expect(!HistoryFilter.isIn(.month(months[0]), d(9, 30), calendar: calendar))
        #expect(HistoryFilter.isIn(.all, d(1, 1), calendar: calendar))
    }

    @Test func monthCountsInOnePass() {
        let d = { (m: Int, day: Int) in calendar.date(from: DateComponents(year: 2026, month: m, day: day, hour: 9))! }
        let counts = HistoryFilter.monthCounts([d(10, 30), d(9, 2), d(10, 1), d(10, 2)], calendar: calendar)
        #expect(counts.map(\.count) == [3, 1])
        #expect(counts.first?.month == calendar.dateInterval(of: .month, for: d(10, 5))!.start)
    }

    @Test func dayFilter() {
        let at = { (day: Int, hour: Int) in calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))! }
        #expect(HistoryFilter.isIn(.day(at(30, 0)), at(30, 23), calendar: calendar))
        #expect(!HistoryFilter.isIn(.day(at(30, 12)), at(29, 23), calendar: calendar))
    }
}
