import Testing
import Foundation
@testable import BPLog

struct BPCategoryTests {
    @Test(arguments: [
        (119, 79, BPCategory.normal),
        (120, 79, .elevated),
        (129, 79, .elevated),
        (130, 70, .stage1),
        (139, 79, .stage1),
        (115, 80, .stage1),
        (115, 89, .stage1),
        (140, 70, .stage2),
        (110, 90, .stage2),
        (180, 120, .stage2),
        (181, 80, .crisis),
        (120, 121, .crisis),
    ])
    func boundaries(systolic: Int, diastolic: Int, expected: BPCategory) {
        #expect(BPCategory.classify(systolic: systolic, diastolic: diastolic) == expected)
    }

    @Test(arguments: [
        (89, 70, BPCategory.low),
        (110, 59, .low),
        (85, 55, .low),
        (90, 60, .normal),
        (120, 55, .elevated),  // high systolic outranks a low diastolic
        (85, 82, .stage1),
    ])
    func low(systolic: Int, diastolic: Int, expected: BPCategory) {
        #expect(BPCategory.classify(systolic: systolic, diastolic: diastolic) == expected)
    }

    @Test func onlyLowHasNote() {
        #expect(BPCategory.low.note != nil)
        #expect(BPCategory.allCases.filter { $0.note != nil } == [.low])
    }

    @Test func higherGradeWins() {
        #expect(BPCategory.classify(systolic: 125, diastolic: 85) == .stage1)
        #expect(BPCategory.classify(systolic: 135, diastolic: 95) == .stage2)
    }

    @Test func validation() {
        #expect(ReadingLimits.isValid(systolic: 120, diastolic: 80, pulse: 70))
        #expect(ReadingLimits.isValid(systolic: 120, diastolic: 80, pulse: nil))
        #expect(!ReadingLimits.isValid(systolic: 80, diastolic: 80, pulse: nil))
        #expect(!ReadingLimits.isValid(systolic: 70, diastolic: 90, pulse: nil))
        #expect(!ReadingLimits.isValid(systolic: 300, diastolic: 80, pulse: nil))
        #expect(!ReadingLimits.isValid(systolic: 120, diastolic: 20, pulse: nil))
        #expect(!ReadingLimits.isValid(systolic: 120, diastolic: 80, pulse: 251))
        #expect(!ReadingLimits.isValid(systolic: 120, diastolic: 80, pulse: 14))
        #expect(ReadingLimits.isValid(systolic: 120, diastolic: 80, pulse: 15))
        #expect(ReadingLimits.isValid(systolic: 120, diastolic: 80, pulse: 250))
    }

    @Test func problemNamesTheActualCause() {
        #expect(ReadingLimits.problem(systolic: 90, diastolic: 20, pulse: nil)!.contains("bottom number should be between"))
        #expect(ReadingLimits.problem(systolic: 300, diastolic: 80, pulse: nil)!.contains("top number should be between"))
        #expect(ReadingLimits.problem(systolic: 80, diastolic: 90, pulse: nil)!.contains("higher than the bottom"))
        #expect(ReadingLimits.problem(systolic: 120, diastolic: 80, pulse: 10)!.contains("Pulse"))
        #expect(ReadingLimits.problem(systolic: 120, diastolic: 80, pulse: 70) == nil)
    }

    @MainActor @Test func settingsPersistAndDefault() {
        let defaults = UserDefaults(suiteName: "BPCategoryTests-\(UUID())")!
        let settings = AppSettings(defaults: defaults)
        #expect(settings.targetSystolic == 130 && settings.targetDiastolic == 80)
        #expect(!settings.hasCompletedOnboarding)
        settings.reminderMinutes = [480, 1200]
        settings.healthEnabled = true
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.reminderMinutes == [480, 1200])
        #expect(reloaded.healthEnabled)
    }
}
