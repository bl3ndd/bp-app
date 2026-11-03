import Foundation
import CoreGraphics

/// Turns text the camera found on a blood pressure monitor's screen into a
/// reading. Pure, so it's testable without a camera; the scanner view feeds it.
///
/// Home monitors show the top number largest and highest, the bottom number
/// under it, and the pulse smaller at the bottom. So: among plausible numbers,
/// the biggest valid top/bottom pair in reading order wins, and the pulse is the
/// largest number left. The person always confirms before anything is saved.
nonisolated enum MonitorReader {
    struct Item: Equatable, Sendable {
        var text: String
        /// Where the text sits, y growing downward (view or image coordinates; only relative sizes matter).
        var rect: CGRect
    }

    struct Result: Equatable, Sendable {
        var systolic: Int
        var diastolic: Int
        var pulse: Int?
    }

    private struct Number {
        var value: Int
        var rect: CGRect
    }

    static func read(_ items: [Item]) -> Result? {
        let numbers = items.flatMap(numbers(in:))
        var best: (result: Result, size: CGFloat)?
        for top in numbers {
            for bottom in numbers where comesBefore(top.rect, bottom.rect) {
                guard ReadingLimits.isValid(systolic: top.value, diastolic: bottom.value, pulse: nil) else { continue }
                let size = top.rect.height + bottom.rect.height
                if size > (best?.size ?? 0) {
                    best = (Result(systolic: top.value, diastolic: bottom.value, pulse: nil), size)
                }
            }
        }
        guard var result = best?.result else { return nil }
        // Each value is used once: a pulse of 82 must not be the 82 already taken as the bottom number.
        var rest = numbers
        for taken in [result.systolic, result.diastolic] {
            if let i = rest.firstIndex(where: { $0.value == taken }) { rest.remove(at: i) }
        }
        result.pulse = rest
            .filter { ReadingLimits.pulse.contains($0.value) }
            .max { $0.rect.height < $1.rect.height }?
            .value
        return result
    }

    /// Two- and three-digit numbers, skipping clock times ("7:42") and dates ("10/30"),
    /// which many monitors show next to the reading.
    private static func numbers(in item: Item) -> [Number] {
        let cleaned = item.text.replacingOccurrences(of: #"\d{1,2}\s*[:./-]\s*\d{1,2}"#, with: " ", options: .regularExpression)
        let tokens = cleaned.matches(of: #/\d+/#).compactMap { Int($0.output) }.filter { (10...999).contains($0) }
        guard !tokens.isEmpty else { return [] }
        // Several numbers in one line of text ("128 82"): split its box evenly left to right.
        let width = item.rect.width / CGFloat(tokens.count)
        return tokens.enumerated().map { i, value in
            Number(value: value, rect: CGRect(x: item.rect.minX + width * CGFloat(i), y: item.rect.minY,
                                              width: width, height: item.rect.height))
        }
    }

    /// Reading order: above, or on the same line and to the left.
    private static func comesBefore(_ a: CGRect, _ b: CGRect) -> Bool {
        if a.maxY <= b.midY { return true }
        let sameLine = abs(a.midY - b.midY) < max(a.height, b.height) / 2
        return sameLine && a.midX < b.midX
    }
}
