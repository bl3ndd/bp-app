import Foundation

/// Pure statistics over readings. No SwiftData, no clock: callers pass the
/// readings, the calendar and "today", so every number is reproducible in tests.
nonisolated enum StatsEngine {
    struct Averages: Equatable, Sendable {
        var systolic: Double
        var diastolic: Double
        /// nil when no reading in the group has a pulse.
        var pulse: Double?
        var count: Int
    }

    struct Trend: Equatable, Sendable {
        var systolicPerWeek: Double
        var diastolicPerWeek: Double
    }

    struct Delta: Equatable, Sendable {
        var systolic: Double
        var diastolic: Double
    }

    /// Fewer points than this, or a shorter span, gives a slope that is mostly noise.
    static let trendMinReadings = 5
    static let trendMinDays = 7.0

    static func readings(_ readings: [ReadingValue], in interval: DateInterval) -> [ReadingValue] {
        readings.filter { interval.contains($0.date) }
    }

    static func averages(_ readings: [ReadingValue]) -> Averages? {
        guard !readings.isEmpty else { return nil }
        let n = Double(readings.count)
        let pulses = readings.compactMap(\.pulse)
        return Averages(
            systolic: Double(readings.map(\.systolic).reduce(0, +)) / n,
            diastolic: Double(readings.map(\.diastolic).reduce(0, +)) / n,
            pulse: pulses.isEmpty ? nil : Double(pulses.reduce(0, +)) / Double(pulses.count),
            count: readings.count
        )
    }

    /// Highest and lowest reading by systolic; ties go to the earlier reading.
    static func extremes(_ readings: [ReadingValue]) -> (highest: ReadingValue, lowest: ReadingValue)? {
        let sorted = readings.sorted { $0.date < $1.date }
        guard let highest = sorted.max(by: { $0.systolic < $1.systolic }),
              let lowest = sorted.min(by: { $0.systolic < $1.systolic }) else { return nil }
        return (highest, lowest)
    }

    /// Average SYS − DIA.
    static func pulsePressure(_ readings: [ReadingValue]) -> Double? {
        mean(readings.map { Double($0.systolic - $0.diastolic) })
    }

    /// Average DIA + (SYS − DIA) / 3.
    static func meanArterialPressure(_ readings: [ReadingValue]) -> Double? {
        mean(readings.map { Double($0.diastolic) + Double($0.systolic - $0.diastolic) / 3 })
    }

    static func categoryDistribution(_ readings: [ReadingValue]) -> [BPCategory: Int] {
        Dictionary(grouping: readings, by: \.category).mapValues(\.count)
    }

    /// Share (0…1) of readings below both targets.
    static func timeInRange(_ readings: [ReadingValue], systolicBelow: Int, diastolicBelow: Int) -> Double? {
        guard !readings.isEmpty else { return nil }
        let inRange = readings.filter { $0.systolic < systolicBelow && $0.diastolic < diastolicBelow }
        return Double(inRange.count) / Double(readings.count)
    }

    /// Morning is before 12:00, evening from 18:00; afternoon readings count in neither.
    static func morningVsEvening(_ readings: [ReadingValue], calendar: Calendar) -> (morning: Averages?, evening: Averages?) {
        let hour = { (r: ReadingValue) in calendar.component(.hour, from: r.date) }
        return (averages(readings.filter { hour($0) < 12 }), averages(readings.filter { hour($0) >= 18 }))
    }

    /// Keyed by `Calendar` weekday (1 = Sunday … 7 = Saturday).
    static func weekdayAverages(_ readings: [ReadingValue], calendar: Calendar) -> [Int: Averages] {
        Dictionary(grouping: readings) { calendar.component(.weekday, from: $0.date) }.compactMapValues(averages)
    }

    /// Keyed by hour of day (0…23).
    static func hourlyAverages(_ readings: [ReadingValue], calendar: Calendar) -> [Int: Averages] {
        Dictionary(grouping: readings) { calendar.component(.hour, from: $0.date) }.compactMapValues(averages)
    }

    /// Least-squares slope in mmHg per week, nil until there's enough data to mean something.
    static func trend(_ readings: [ReadingValue]) -> Trend? {
        guard readings.count >= trendMinReadings,
              let first = readings.map(\.date).min(),
              let last = readings.map(\.date).max(),
              last.timeIntervalSince(first) >= trendMinDays * 86_400 else { return nil }
        let weeks = readings.map { $0.date.timeIntervalSince(first) / (7 * 86_400) }
        guard let sys = slope(x: weeks, y: readings.map { Double($0.systolic) }),
              let dia = slope(x: weeks, y: readings.map { Double($0.diastolic) }) else { return nil }
        return Trend(systolicPerWeek: sys, diastolicPerWeek: dia)
    }

    /// Current period average minus the previous period average.
    static func periodComparison(current: [ReadingValue], previous: [ReadingValue]) -> Delta? {
        guard let now = averages(current), let before = averages(previous) else { return nil }
        return Delta(systolic: now.systolic - before.systolic, diastolic: now.diastolic - before.diastolic)
    }

    /// Consecutive days with at least one reading, ending today — or yesterday,
    /// so the streak doesn't drop to zero in the morning before the first reading.
    static func streak(_ readings: [ReadingValue], today: Date, calendar: Calendar) -> Int {
        let days = Set(readings.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// One reading per calendar day, its values the day's rounded averages,
    /// oldest first. People take several readings a day (doctors suggest 2–3
    /// in a row, morning and evening); without this a day with six readings
    /// would outweigh a day with one in every average, trend and percentage.
    static func daily(_ readings: [ReadingValue], calendar: Calendar) -> [ReadingValue] {
        dailyAverages(readings, calendar: calendar).map { day, avg in
            ReadingValue(date: day, systolic: Int(avg.systolic.rounded()), diastolic: Int(avg.diastolic.rounded()),
                         pulse: avg.pulse.map { Int($0.rounded()) })
        }
    }

    /// One averaged point per calendar day, oldest first — the chart's "daily average" mode.
    static func dailyAverages(_ readings: [ReadingValue], calendar: Calendar) -> [(day: Date, averages: Averages)] {
        periodAverages(readings, by: .day, calendar: calendar)
    }

    /// One averaged point per day, week or month, oldest first, dated at the
    /// period's start. Long charts use weeks or months so years of readings
    /// stay readable instead of turning into a solid band.
    static func periodAverages(_ readings: [ReadingValue], by component: Calendar.Component,
                               calendar: Calendar) -> [(day: Date, averages: Averages)] {
        Dictionary(grouping: readings) { calendar.dateInterval(of: component, for: $0.date)?.start ?? calendar.startOfDay(for: $0.date) }
            .compactMap { start, group in averages(group).map { (start, $0) } }
            .sorted { $0.day < $1.day }
    }

    /// How coarse a chart's points should be for a span of history.
    enum ChartBucket: Equatable, Sendable {
        case day, week, month

        var component: Calendar.Component {
            switch self {
            case .day: .day
            case .week: .weekOfYear
            case .month: .month
            }
        }

        var label: String {
            switch self {
            case .day: "Daily averages"
            case .week: "Weekly averages"
            case .month: "Monthly averages"
            }
        }

        /// Days for up to ~4 months, weeks up to ~13 months, months beyond:
        /// at most ~60 points for a typical history.
        static func forSpan(days: Int) -> ChartBucket {
            days > 400 ? .month : days > 120 ? .week : .day
        }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func slope(x: [Double], y: [Double]) -> Double? {
        guard let mx = mean(x), let my = mean(y) else { return nil }
        let variance = x.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard variance > 0 else { return nil }
        let covariance = zip(x, y).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        return covariance / variance
    }
}
