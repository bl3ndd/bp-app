import Foundation

/// History search and month filter, kept pure so they're testable without SwiftData.
nonisolated enum HistoryFilter {
    struct Item {
        var value: ReadingValue
        var tags: [String]
        var note: String
    }

    /// Every word of the query must match: a number ("130"), "128/82", a category
    /// ("stage 2", "low"), a tag or note text. Case-insensitive.
    static func matches(_ item: Item, query: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return true }
        let v = item.value
        let haystack = ([
            "\(v.systolic)/\(v.diastolic)",
            v.category.title,
            v.category.shortTitle,
            item.note,
        ] + item.tags).joined(separator: " ").lowercased()
        let numbers = Set([v.systolic, v.diastolic] + (v.pulse.map { [$0] } ?? []))
        let tokens = Set(haystack.split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == "·" }).map(String.init))
        return words.allSatisfy { word in
            // A number is a reading value or a whole word ("stage 2"), never a fragment ("13" ≠ 130).
            if let n = Int(word) { return numbers.contains(n) || tokens.contains(word) }
            return haystack.contains(word)
        }
    }

    /// First day of each month that has readings, newest first.
    static func months(_ dates: [Date], calendar: Calendar) -> [Date] {
        monthCounts(dates, calendar: calendar).map(\.month)
    }

    /// Months with readings and how many, newest first, in one pass. (Counting
    /// each month against every reading took 0.2 s at 3,800 readings.)
    static func monthCounts(_ dates: [Date], calendar: Calendar) -> [(month: Date, count: Int)] {
        var counts: [Date: Int] = [:]
        for date in dates {
            if let start = calendar.dateInterval(of: .month, for: date)?.start { counts[start, default: 0] += 1 }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.month > $1.month }
    }

    /// Which readings History shows.
    enum Scope: Hashable {
        case all
        case month(Date)
        case day(Date)
    }

    static func isIn(_ scope: Scope, _ date: Date, calendar: Calendar) -> Bool {
        switch scope {
        case .all: true
        case .month(let month): calendar.isDate(date, equalTo: month, toGranularity: .month)
        case .day(let day): calendar.isDate(date, inSameDayAs: day)
        }
    }
}
