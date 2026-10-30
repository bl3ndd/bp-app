import Testing
@testable import BPLog

struct EntryInputTests {
    @Test func sanitizeKeepsThreeDigits() {
        #expect(EntryInput.sanitize("12a8") == "128")
        #expect(EntryInput.sanitize("1234") == "123")
        #expect(EntryInput.sanitize("") == "")
    }

    @Test(arguments: [
        ("128", true), ("95", true), ("82", true), ("70", true),
        ("12", false), ("10", false), ("21", false), ("1", false), ("", false),
    ])
    func completeness(text: String, done: Bool) {
        #expect(EntryInput.isComplete(text) == done)
    }
}

extension EntryInputTests {
    @Test func nonASCIIDigitsAreDropped() {
        #expect(EntryInput.sanitize("١٢٨") == "")  // Arabic-Indic 128: Int() can't read it
        #expect(EntryInput.sanitize("1٢8") == "18")
    }
}
