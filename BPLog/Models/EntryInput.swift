import Foundation

/// Typing rules for the number fields, so entry needs no "Next" taps.
nonisolated enum EntryInput {
    /// Keeps digits only, at most three.
    static func sanitize(_ text: String) -> String {
        String(text.filter(\.isNumber).prefix(3))
    }

    /// A value is finished at three digits, or at two when it can't grow into a
    /// plausible three-digit one: "95" is done, "12" is on its way to "128".
    static func isComplete(_ text: String) -> Bool {
        text.count == 3 || (text.count == 2 && !["1", "2"].contains(text.first))
    }
}
