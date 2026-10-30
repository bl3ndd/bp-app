import Testing
import Foundation
import PDFKit
@testable import BPLog

@MainActor
struct PDFGeneratorTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func readings(_ count: Int) -> [ReportReading] {
        (0..<count).map { i in
            ReportReading(value: ReadingValue(date: now.addingTimeInterval(-Double(i) * 6 * 3600), systolic: 120 + i % 30,
                                              diastolic: 75 + i % 15, pulse: 70),
                          arm: "left", position: "sitting", tags: i % 3 == 0 ? ["Stressed"] : [], note: i % 5 == 0 ? "after walk" : "")
        }
    }

    private func document(_ url: URL) throws -> PDFDocument {
        try #require(PDFDocument(url: url))
    }

    @Test func reportHasSummaryTableAndDisclaimer() throws {
        let url = PDFGenerator.generate(readings: Self.readings(10), interval: nil, patientName: "Jane Doe", now: Self.now)
        // PDF text extraction breaks wrapped lines with newlines; compare on single spaces.
        let text = (try document(url).string ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(text.contains("Blood Pressure Report"))
        #expect(text.contains("Jane Doe"))
        #expect(text.contains("Summary"))
        #expect(text.contains("All readings"))
        #expect(text.contains("not a medical device"))
        #expect(text.contains("after walk"))
    }

    @Test func usLetterPages() throws {
        let page = try #require(try document(PDFGenerator.generate(readings: Self.readings(3), interval: nil, patientName: "", now: Self.now)).page(at: 0))
        let box = page.bounds(for: .mediaBox)
        #expect(box.width == 612 && box.height == 792)
    }

    @Test func pagesGrowWithReadings() throws {
        let few = try document(PDFGenerator.generate(readings: Self.readings(5), interval: nil, patientName: "", now: Self.now)).pageCount
        let many = try document(PDFGenerator.generate(readings: Self.readings(300), interval: nil, patientName: "", now: Self.now)).pageCount
        #expect(few >= 1)
        #expect(many > few)
    }

    @Test func emptyReportStillRenders() throws {
        let doc = try document(PDFGenerator.generate(readings: [], interval: nil, patientName: "", now: Self.now))
        #expect(doc.pageCount == 1)
        #expect((doc.string ?? "").contains("No readings in this period"))
    }
}
