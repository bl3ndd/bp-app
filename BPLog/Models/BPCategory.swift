import Foundation

/// AHA/ACC 2017 blood pressure categories. A reference table shown next to a
/// reading — the app never diagnoses or advises (guideline 1.4.1).
nonisolated enum BPCategory: Int, CaseIterable, Comparable, Sendable {
    case low = -1, normal, elevated, stage1, stage2, crisis

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Below 90/60 — the common US threshold (NHLBI, AHA). The AHA table itself
    /// covers only high readings, so without this 85/55 would read as Normal.
    static let lowSystolic = 90
    static let lowDiastolic = 60

    /// Systolic and diastolic are graded separately and the higher grade wins,
    /// so 125/85 is Stage 1 (by diastolic), not Elevated. Low applies only when
    /// nothing is high.
    static func classify(systolic: Int, diastolic: Int) -> BPCategory {
        let high = max(grade(systolic: systolic), grade(diastolic: diastolic))
        if high == .normal, systolic < lowSystolic || diastolic < lowDiastolic { return .low }
        return high
    }

    private static func grade(systolic: Int) -> BPCategory {
        switch systolic {
        case 181...: .crisis
        case 140...: .stage2
        case 130...: .stage1
        case 120...: .elevated
        default: .normal
        }
    }

    /// Diastolic has no "elevated" band: under 80 is normal whatever the systolic.
    private static func grade(diastolic: Int) -> BPCategory {
        switch diastolic {
        case 121...: .crisis
        case 90...: .stage2
        case 80...: .stage1
        default: .normal
        }
    }

    var title: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .elevated: "Elevated"
        case .stage1: "High · Stage 1"
        case .stage2: "High · Stage 2"
        case .crisis: "Hypertensive crisis"
        }
    }

    /// One plain-language line under the badge where a category needs it. Points to the doctor, never advises.
    var note: String? {
        switch self {
        case .low: "Below 90/60. If you feel dizzy or faint, talk to your doctor."
        default: nil
        }
    }
}

/// Plausible input ranges. Anything outside is a typo, not a reading.
nonisolated enum ReadingLimits {
    static let systolic = 60...260
    static let diastolic = 30...160
    static let pulse = 15...250

    static func isValid(systolic: Int, diastolic: Int, pulse: Int?) -> Bool {
        problem(systolic: systolic, diastolic: diastolic, pulse: pulse) == nil
    }

    /// What's wrong, in words the user can act on; nil when the reading is fine.
    static func problem(systolic: Int, diastolic: Int, pulse: Int?) -> String? {
        if !Self.systolic.contains(systolic) {
            return "The top number should be between \(Self.systolic.lowerBound) and \(Self.systolic.upperBound)."
        }
        if !Self.diastolic.contains(diastolic) {
            return "The bottom number should be between \(Self.diastolic.lowerBound) and \(Self.diastolic.upperBound)."
        }
        if systolic <= diastolic {
            return "The top number should be higher than the bottom one."
        }
        if let pulse, !Self.pulse.contains(pulse) {
            return "Pulse should be between \(Self.pulse.lowerBound) and \(Self.pulse.upperBound)."
        }
        return nil
    }
}
