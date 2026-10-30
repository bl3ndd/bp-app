import Testing
import Foundation
import UserNotifications
@testable import BPLog

struct RemindersTests {
    @Test func oneRepeatingRequestPerTime() throws {
        let requests = NotificationService.requests(minutes: [1200, 480, 480])
        #expect(requests.map(\.identifier) == ["reading-reminder-480", "reading-reminder-1200"])
        let trigger = try #require(requests[0].trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 8 && trigger.dateComponents.minute == 0)
        #expect(requests[0].content.body.contains("morning"))
        #expect(requests[1].content.body.contains("Evening"))
        #expect(NotificationService.requests(minutes: []).isEmpty)
    }

    @Test func timeConversionRoundTrips() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        for minutes in [0, 480, 755, 1200, 1439] {
            let date = ReminderTime.date(fromMinutes: minutes, calendar: calendar, on: day)
            #expect(ReminderTime.minutes(from: date, calendar: calendar) == minutes)
        }
        #expect(ReminderTime.isMorning(719))
        #expect(!ReminderTime.isMorning(720))
    }
}

@MainActor
@Suite(.serialized)
struct ReviewServiceTests {
    private func run(_ categories: [BPCategory]) -> Int {
        let defaults = UserDefaults(suiteName: "ReviewServiceTests-\(UUID())")!
        var prompts = 0
        let (savedDefaults, savedPrompt) = (ReviewService.defaults, ReviewService.prompt)
        ReviewService.defaults = defaults
        ReviewService.prompt = { prompts += 1 }
        defer { ReviewService.defaults = savedDefaults; ReviewService.prompt = savedPrompt }
        categories.forEach(ReviewService.recordReading)
        return prompts
    }

    @Test func promptsOnceAtThreshold() {
        #expect(run(Array(repeating: .normal, count: ReviewService.threshold - 1)) == 0)
        #expect(run(Array(repeating: .normal, count: ReviewService.threshold + 3)) == 1)
    }

    @Test func neverRightAfterACrisisReading() {
        let readings = Array(repeating: BPCategory.normal, count: ReviewService.threshold - 1) + [.crisis]
        #expect(run(readings) == 0)
        #expect(run(readings + [.normal]) == 1)
    }
}
