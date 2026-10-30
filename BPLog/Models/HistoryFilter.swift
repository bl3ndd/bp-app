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
        let starts = Set(dates.compactMap { calendar.dateInterval(of: .month, for: $0)?.start })
        return starts.sorted(by: >)
    }

    static func isIn(month: Date?, _ date: Date, calendar: Calendar) -> Bool {
        guard let month else { return true }
        return calendar.isDate(date, equalTo: month, toGranularity: .month)
    }
}
