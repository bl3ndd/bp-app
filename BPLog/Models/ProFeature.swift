import Foundation

/// Everything behind the one-time Pro unlock. Logging, history, Apple Health,
/// short charts, backup, reminders and scanning a monitor are never gated: the data is the user's.
nonisolated enum ProFeature: Sendable {
    case pdfReport, fullStats, longChartRanges, people

    /// The single gating predicate every view goes through.
    static func isLocked(_ feature: ProFeature, isPro: Bool) -> Bool {
        !isPro
    }
}

extension ChartRange {
    /// 7 and 30 days are free; longer history is Pro.
    var feature: ProFeature? {
        switch self {
        case .week, .month: nil
        case .quarter, .year, .all: .longChartRanges
        }
    }
}
