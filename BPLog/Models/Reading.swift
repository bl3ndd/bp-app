import Foundation
import SwiftData

nonisolated enum Arm: String, CaseIterable, Sendable { case left, right }
nonisolated enum Position: String, CaseIterable, Sendable { case sitting, standing, lying }
nonisolated enum ReadingSource: String, Sendable { case manual, health }

/// One blood pressure measurement. Enums are stored as raw strings and every
/// property has a default, so the schema can grow without migrations.
@Model
final class Reading {
    var id: UUID = UUID()
    var date: Date = Date()
    var systolic: Int = 120
    var diastolic: Int = 80
    var pulse: Int?
    var armRaw: String = Arm.left.rawValue
    var positionRaw: String = Position.sitting.rawValue
    var tags: [String] = []
    var note: String = ""
    var sourceRaw: String = ReadingSource.manual.rawValue
    /// The Health correlation this reading came from or was written to.
    /// Used to skip re-imports and to delete our own writes from Health.
    var healthKitID: UUID?

    init(date: Date = Date(), systolic: Int, diastolic: Int, pulse: Int? = nil,
         arm: Arm = .left, position: Position = .sitting, tags: [String] = [], note: String = "",
         source: ReadingSource = .manual, healthKitID: UUID? = nil) {
        self.date = date
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.armRaw = arm.rawValue
        self.positionRaw = position.rawValue
        self.tags = tags
        self.note = note
        self.sourceRaw = source.rawValue
        self.healthKitID = healthKitID
    }

    var arm: Arm {
        get { Arm(rawValue: armRaw) ?? .left }
        set { armRaw = newValue.rawValue }
    }

    var position: Position {
        get { Position(rawValue: positionRaw) ?? .sitting }
        set { positionRaw = newValue.rawValue }
    }

    var source: ReadingSource {
        get { ReadingSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var category: BPCategory { BPCategory.classify(systolic: systolic, diastolic: diastolic) }

    var value: ReadingValue { ReadingValue(date: date, systolic: systolic, diastolic: diastolic, pulse: pulse) }
}

/// Plain snapshot of a reading for statistics and exports — testable without SwiftData.
nonisolated struct ReadingValue: Equatable, Sendable {
    var date: Date
    var systolic: Int
    var diastolic: Int
    var pulse: Int?

    var category: BPCategory { BPCategory.classify(systolic: systolic, diastolic: diastolic) }
}
