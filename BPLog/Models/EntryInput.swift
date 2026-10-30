import Foundation

/// Typing rules for the number fields, so entry needs no "Next" taps.
nonisolated enum EntryInput {
    /// Keeps ASCII digits only, at most three, without leading zeros: no blood
    /// pressure or pulse starts with 0, and a stray "0" (seen arriving in Pulse
    /// during fast automated typing) must not leave a value that blocks Save.
    static func sanitize(_ text: String) -> String {
        let digits = text.filter { $0.isASCII && $0.isNumber }.drop { $0 == "0" }
        return String(digits.prefix(3))
    }

    /// A value is finished at three digits, or at two when it can't grow into a
    /// plausible three-digit one: "95" is done, "12" is on its way to "128".
    static func isComplete(_ text: String) -> Bool {
        text.count == 3 || (text.count == 2 && !["1", "2"].contains(text.first))
    }
}
