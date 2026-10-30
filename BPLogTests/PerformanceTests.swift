import Testing
import Foundation
@testable import BPLog

/// Long histories must stay fast: ~2 readings a day is ~700 a year, so 3,000–5,000
/// is a realistic multi-year user. Budgets are generous; durations are printed.
@MainActor
struct PerformanceTests {
    let now = Date()
    let calendar = Calendar.current

    private func time(_ label: String, _ work: () -> Void) -> Duration {
        let elapsed = ContinuousClock().measure(work)
        print("PERF \(label): \(elapsed)")
        return elapsed
    }

    @Test func statisticsOnFiveThousandReadings() {
        let readings = DemoData.samples(now: now, calendar: calendar, days: 5 * 365).map(\.value)
        #expect(readings.count > 3000)
        let elapsed = time("stats \(readings.count) readings") {
            let days = StatsEngine.daily(readings, calendar: calendar)
            _ = StatsEngine.averages(days)
            _ = StatsEngine.trend(days)
            _ = StatsEngine.categoryDistribution(days)
            _ = StatsEngine.timeInRange(days, systolicBelow: 130, diastolicBelow: 80)
            _ = StatsEngine.weekdayAverages(days, calendar: calendar)
            _ = StatsEngine.morningVsEvening(readings, calendar: calendar)
            _ = StatsEngine.extremes(readings)
            _ = StatsEngine.streak(readings, today: now, calendar: calendar)
        }
        #expect(elapsed < .milliseconds(300))
    }

    @Test func doctorReportOnThreeThousandReadings() throws {
        let readings = DemoData.samples(now: now, calendar: calendar, days: 3 * 365)
            .map { ReportReading(value: $0.value, arm: "left", position: "sitting", tags: $0.tags, note: "") }
        var url: URL?
        let elapsed = time("PDF \(readings.count) readings") {
            url = PDFGenerator.generate(readings: readings, interval: nil, patientName: "", now: now)
        }
        let size = try FileManager.default.attributesOfItem(atPath: try #require(url).path)[.size] as? Int ?? 0
        print("PERF PDF size: \(size / 1024) KB")
        #expect(elapsed < .seconds(8))
    }
}
