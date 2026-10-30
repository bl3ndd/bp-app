import Testing
import Foundation
@testable import BPLog

struct StatsEngineTests {
    /// Fixed UTC Gregorian calendar so hour/weekday buckets don't depend on the device.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-10-05 is a Monday.
    static func date(day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    static func r(_ sys: Int, _ dia: Int, _ pulse: Int? = nil, day: Int = 5, hour: Int = 9) -> ReadingValue {
        ReadingValue(date: date(day: day, hour: hour), systolic: sys, diastolic: dia, pulse: pulse)
    }

    let cal = StatsEngineTests.calendar

    @Test func emptyInputGivesNoNumbers() {
        #expect(StatsEngine.averages([]) == nil)
        #expect(StatsEngine.extremes([]) == nil)
        #expect(StatsEngine.pulsePressure([]) == nil)
        #expect(StatsEngine.meanArterialPressure([]) == nil)
        #expect(StatsEngine.timeInRange([], systolicBelow: 130, diastolicBelow: 80) == nil)
        #expect(StatsEngine.trend([]) == nil)
        #expect(StatsEngine.categoryDistribution([]).isEmpty)
        #expect(StatsEngine.streak([], today: Self.date(day: 10), calendar: cal) == 0)
    }

    @Test func averagesIgnoreMissingPulse() {
        let a = StatsEngine.averages([Self.r(120, 80, 60), Self.r(140, 90, nil), Self.r(130, 70, 80)])!
        #expect(a.systolic == 130)
        #expect(a.diastolic == 80)
        #expect(a.pulse == 70)
        #expect(a.count == 3)
        #expect(StatsEngine.averages([Self.r(120, 80)])!.pulse == nil)
    }

    @Test func extremesBySystolic() {
        let low = Self.r(110, 70, day: 6)
        let high = Self.r(150, 95, day: 7)
        let e = StatsEngine.extremes([Self.r(130, 80, day: 5), low, high])!
        #expect(e.highest == high)
        #expect(e.lowest == low)
    }

    @Test func pulsePressureAndMAP() {
        let readings = [Self.r(120, 80), Self.r(150, 90)]
        #expect(StatsEngine.pulsePressure(readings) == 50)  // (40 + 60) / 2
        // MAP: 80 + 40/3 = 93.33…, 90 + 60/3 = 110 → 101.66…
        #expect(abs(StatsEngine.meanArterialPressure(readings)! - 101.6667) < 0.001)
    }

    @Test func categoryDistributionCounts() {
        let d = StatsEngine.categoryDistribution([Self.r(115, 75), Self.r(118, 70), Self.r(135, 85), Self.r(185, 100)])
        #expect(d[.normal] == 2)
        #expect(d[.stage1] == 1)
        #expect(d[.crisis] == 1)
        #expect(d[.stage2] == nil)
    }

    @Test func timeInRangeNeedsBothBelowTarget() {
        let readings = [Self.r(125, 75), Self.r(129, 79), Self.r(130, 70), Self.r(120, 80)]
        #expect(StatsEngine.timeInRange(readings, systolicBelow: 130, diastolicBelow: 80) == 0.5)
    }

    @Test func morningVsEveningBoundaries() {
        let readings = [
            Self.r(120, 80, hour: 7), Self.r(130, 84, hour: 11),  // morning
            Self.r(200, 100, hour: 12), Self.r(200, 100, hour: 17),  // afternoon, ignored
            Self.r(140, 90, hour: 18), Self.r(150, 96, hour: 23),  // evening
        ]
        let split = StatsEngine.morningVsEvening(readings, calendar: cal)
        #expect(split.morning?.systolic == 125)
        #expect(split.morning?.count == 2)
        #expect(split.evening?.systolic == 145)
        #expect(split.evening?.diastolic == 93)
        #expect(StatsEngine.morningVsEvening([Self.r(120, 80, hour: 7)], calendar: cal).evening == nil)
    }

    @Test func weekdayAndHourBuckets() {
        let readings = [Self.r(120, 80, day: 5, hour: 8), Self.r(140, 90, day: 12, hour: 8), Self.r(130, 85, day: 6, hour: 20)]
        let weekdays = StatsEngine.weekdayAverages(readings, calendar: cal)
        #expect(weekdays[2]?.systolic == 130)  // two Mondays
        #expect(weekdays[3]?.count == 1)  // Tuesday
        let hours = StatsEngine.hourlyAverages(readings, calendar: cal)
        #expect(hours[8]?.count == 2)
        #expect(hours[20]?.systolic == 130)
    }

    @Test func trendSign() {
        // +1 mmHg SYS and +0.5 DIA per day over 10 days → +7 / +3.5 per week.
        let rising = (0..<10).map { Self.r(120 + $0, 80 + $0 / 2 * 1, day: 5 + $0) }
        let t = StatsEngine.trend(rising)!
        #expect(abs(t.systolicPerWeek - 7) < 0.0001)
        #expect(t.diastolicPerWeek > 0)
        let falling = (0..<10).map { Self.r(150 - 2 * $0, 95, day: 5 + $0) }
        let f = StatsEngine.trend(falling)!
        #expect(abs(f.systolicPerWeek + 14) < 0.0001)
        #expect(f.diastolicPerWeek == 0)
    }

    @Test func trendNeedsEnoughData() {
        let fourReadings = (0..<4).map { Self.r(120 + $0, 80, day: 5 + $0 * 3) }
        #expect(StatsEngine.trend(fourReadings) == nil)
        let shortSpan = (0..<6).map { Self.r(120 + $0, 80, day: 5 + $0) }  // 5 days
        #expect(StatsEngine.trend(shortSpan) == nil)
    }

    @Test func periodComparison() {
        let delta = StatsEngine.periodComparison(current: [Self.r(130, 85)], previous: [Self.r(140, 80), Self.r(120, 80)])
        #expect(delta == StatsEngine.Delta(systolic: 0, diastolic: 5))
        #expect(StatsEngine.periodComparison(current: [Self.r(130, 85)], previous: []) == nil)
    }

    @Test func streakCountsBackFromTodayOrYesterday() {
        let readings = [Self.r(120, 80, day: 10), Self.r(120, 80, day: 9), Self.r(125, 80, day: 9, hour: 20), Self.r(120, 80, day: 8), Self.r(120, 80, day: 6)]
        #expect(StatsEngine.streak(readings, today: Self.date(day: 10, hour: 22), calendar: cal) == 3)
        #expect(StatsEngine.streak(readings, today: Self.date(day: 11), calendar: cal) == 3)  // nothing yet today
        #expect(StatsEngine.streak(readings, today: Self.date(day: 12), calendar: cal) == 0)  // missed yesterday
    }

    @Test func dailyAveragesOldestFirst() {
        let days = StatsEngine.dailyAverages([Self.r(140, 90, day: 7), Self.r(120, 80, day: 5), Self.r(130, 70, day: 5, hour: 21)], calendar: cal)
        #expect(days.count == 2)
        #expect(days[0].day == Self.calendar.startOfDay(for: Self.date(day: 5)))
        #expect(days[0].averages.systolic == 125)
        #expect(days[1].averages.systolic == 140)
    }

    @Test func dailyGivesEachDayOneVote() {
        // Five high readings on one day, one normal reading on another.
        let busy = (0..<5).map { Self.r(150, 95, 80, day: 5, hour: 7 + $0) }
        let quiet = [Self.r(110, 70, 60, day: 6)]
        let days = StatsEngine.daily(busy + quiet, calendar: cal)
        #expect(days.count == 2)
        #expect(days[0] == ReadingValue(date: Self.calendar.startOfDay(for: Self.date(day: 5)), systolic: 150, diastolic: 95, pulse: 80))
        #expect(StatsEngine.averages(days)!.systolic == 130)  // raw average would be 143.3
        #expect(StatsEngine.categoryDistribution(days) == [.stage2: 1, .normal: 1])
    }

    @Test func dailyRoundsHalfUp() {
        let days = StatsEngine.daily([Self.r(121, 80, day: 5), Self.r(122, 81, day: 5, hour: 20)], calendar: cal)
        #expect(days.first?.systolic == 122)  // 121.5
        #expect(days.first?.diastolic == 81)  // 80.5
        #expect(days.first?.pulse == nil)
    }

    @Test func intervalFilter() {
        let interval = DateInterval(start: Self.date(day: 6, hour: 0), end: Self.date(day: 8, hour: 0))
        let inside = StatsEngine.readings([Self.r(120, 80, day: 5), Self.r(130, 80, day: 6), Self.r(140, 80, day: 7), Self.r(150, 80, day: 9)], in: interval)
        #expect(inside.map(\.systolic) == [130, 140])
    }
}
