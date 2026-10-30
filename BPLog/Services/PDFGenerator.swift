import SwiftUI
import Charts
import UIKit

/// A reading with everything the report table shows.
nonisolated struct ReportReading: Sendable {
    var value: ReadingValue
    var arm: String
    var position: String
    var tags: [String]
    var note: String
}

extension ReportReading {
    init(_ r: Reading) {
        self.init(value: r.value, arm: r.armRaw, position: r.positionRaw, tags: r.tags, note: r.note)
    }
}

/// The doctor report: a one-page summary built on daily averages, a chart,
/// then every reading. US Letter, since the audience is US patients and their
/// doctors' printers.
enum PDFGenerator {
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 48
    private static let footerHeight: CGFloat = 40
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }

    private static let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
    private static let headingFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 10.5)
    private static let smallFont = UIFont.systemFont(ofSize: 8.5)
    private static let figureFont = UIFont.systemFont(ofSize: 20, weight: .bold)
    private static let tableFont = UIFont.systemFont(ofSize: 9)
    private static let tableBold = UIFont.systemFont(ofSize: 9, weight: .semibold)

    static let disclaimer = "Readings were taken by the patient with a home blood pressure monitor and recorded in Simply BP. Simply BP is not a medical device. Categories follow the 2017 ACC/AHA guideline; \"Low\" marks readings below 90/60."

    static func generate(readings: [ReportReading], interval: DateInterval?, patientName: String,
                         targetSystolic: Int = 130, targetDiastolic: Int = 80,
                         now: Date = Date(), calendar: Calendar = .current) -> URL {
        let rows = readings.sorted { $0.value.date < $1.value.date }
        let values = rows.map(\.value)
        let days = StatsEngine.daily(values, calendar: calendar)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("report-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Blood Pressure Report \(now.formatted(.iso8601.year().month().day())).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let chartImage = days.count > 1 ? renderChart(days) : nil

        let data = renderer.pdfData { context in
            var y: CGFloat = 0
            var page = 0
            let bottom = pageHeight - margin - footerHeight

            func newPage() {
                context.beginPage()
                page += 1
                y = margin
                drawFooter(page: page)
            }

            func ensure(_ needed: CGFloat) -> Bool {
                if y + needed > bottom { newPage(); return true }
                return false
            }

            func text(_ s: String, _ font: UIFont, color: UIColor = .black, x: CGFloat = margin, width: CGFloat = contentWidth) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let h = (s as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                     options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil).height
                _ = ensure(h + 4)
                (s as NSString).draw(in: CGRect(x: x, y: y, width: width, height: h + 2), withAttributes: attrs)
                y += h + 4
            }

            func heading(_ s: String) {
                _ = ensure(40)
                y += 10
                text(s, headingFont)
                UIColor(white: 0.85, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: 0.75))
                y += 6
            }

            func figure(_ caption: String, _ value: String, _ sub: String?, color: UIColor, column: Int, of columns: Int) {
                let w = contentWidth / CGFloat(columns)
                let x = margin + w * CGFloat(column)
                (caption as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: smallFont, .foregroundColor: UIColor.darkGray])
                (value as NSString).draw(at: CGPoint(x: x, y: y + 12), withAttributes: [.font: figureFont, .foregroundColor: color])
                if let sub {
                    (sub as NSString).draw(at: CGPoint(x: x, y: y + 38), withAttributes: [.font: smallFont, .foregroundColor: color])
                }
            }

            func line(_ label: String, _ value: String) {
                _ = ensure(16)
                (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: bodyFont, .foregroundColor: UIColor.darkGray])
                (value as NSString).draw(at: CGPoint(x: margin + 190, y: y), withAttributes: [.font: tableBold.withSize(10.5), .foregroundColor: UIColor.black])
                y += 16
            }

            // MARK: Header
            newPage()
            text("Blood Pressure Report", titleFont)
            if !patientName.trimmingCharacters(in: .whitespaces).isEmpty { text(patientName, headingFont) }
            let start = interval?.start ?? values.first?.date ?? now
            let end = interval?.end ?? now
            text("Period: \(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))    Generated: \(now.formatted(date: .abbreviated, time: .omitted))",
                 bodyFont, color: .darkGray)

            // MARK: Summary
            heading("Summary")
            if let avg = StatsEngine.averages(days) {
                let sys = Int(avg.systolic.rounded())
                let dia = Int(avg.diastolic.rounded())
                let category = BPCategory.classify(systolic: sys, diastolic: dia)
                _ = ensure(56)
                figure("AVERAGE (DAILY)", "\(sys)/\(dia) mmHg", category.title, color: uiColor(category), column: 0, of: 3)
                figure("AVERAGE PULSE", avg.pulse.map { "\(Int($0.rounded())) bpm" } ?? "—", nil, color: .black, column: 1, of: 3)
                figure("READINGS", "\(values.count)", "on \(days.count) \(days.count == 1 ? "day" : "days")", color: .black, column: 2, of: 3)
                y += 56

                if let e = StatsEngine.extremes(values) {
                    line("Highest", "\(e.highest.systolic)/\(e.highest.diastolic) on \(e.highest.date.formatted(date: .abbreviated, time: .shortened))")
                    line("Lowest", "\(e.lowest.systolic)/\(e.lowest.diastolic) on \(e.lowest.date.formatted(date: .abbreviated, time: .shortened))")
                }
                let split = StatsEngine.morningVsEvening(values, calendar: calendar)
                line("Morning average (before noon)", split.morning.map(pair) ?? "—")
                line("Evening average (after 6 PM)", split.evening.map(pair) ?? "—")
                if let share = StatsEngine.timeInRange(days, systolicBelow: targetSystolic, diastolicBelow: targetDiastolic) {
                    line("Days below \(targetSystolic)/\(targetDiastolic)", "\(Int((share * 100).rounded()))%")
                }
                if let trend = StatsEngine.trend(days) {
                    line("Trend", "\(signed(trend.systolicPerWeek))/\(signed(trend.diastolicPerWeek)) mmHg per week")
                }
                let distribution = StatsEngine.categoryDistribution(days)
                let parts = BPCategory.allCases.compactMap { c in
                    distribution[c].map { "\(c.title) \(Int((Double($0) / Double(days.count) * 100).rounded()))%" }
                }
                line("Days by category", parts.joined(separator: " · "))
                text("Averages count each day once: several readings on the same day are averaged first.", smallFont, color: .darkGray)
            } else {
                text("No readings in this period.", bodyFont)
            }

            // MARK: Chart
            if let chartImage {
                heading("Daily averages")
                let h = contentWidth * chartImage.size.height / chartImage.size.width
                _ = ensure(h)
                chartImage.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: h))
                y += h + 4
            }

            // MARK: Table
            guard !rows.isEmpty else { return }
            heading("All readings")
            let columns: [(String, CGFloat)] = [("Date", 0.17), ("Time", 0.11), ("BP (mmHg)", 0.13), ("Pulse", 0.08),
                                                ("Category", 0.15), ("Arm / position", 0.14), ("Notes", 0.22)]
            func tableHeader() {
                var x = margin
                for (title, share) in columns {
                    (title as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: tableBold, .foregroundColor: UIColor.darkGray])
                    x += contentWidth * share
                }
                y += 14
            }
            _ = ensure(30)
            tableHeader()
            for (i, r) in rows.enumerated() {
                let notes = (r.tags + (r.note.isEmpty ? [] : [r.note])).joined(separator: "; ")
                let cells = [r.value.date.formatted(date: .abbreviated, time: .omitted),
                             r.value.date.formatted(date: .omitted, time: .shortened),
                             "\(r.value.systolic)/\(r.value.diastolic)",
                             r.value.pulse.map(String.init) ?? "—",
                             r.value.category.title,
                             "\(r.arm.capitalized) / \(r.position.capitalized)",
                             notes]
                let notesWidth = contentWidth * columns[6].1 - 4
                let notesHeight = (notes as NSString).boundingRect(with: CGSize(width: notesWidth, height: .greatestFiniteMagnitude),
                                                                   options: [.usesLineFragmentOrigin], attributes: [.font: tableFont], context: nil).height
                let rowHeight = max(14, notesHeight + 3)
                if ensure(rowHeight) { tableHeader() }
                if i.isMultiple(of: 2) {
                    UIColor(white: 0.96, alpha: 1).setFill()
                    UIRectFill(CGRect(x: margin - 4, y: y - 1, width: contentWidth + 8, height: rowHeight))
                }
                var x = margin
                for (c, cell) in cells.enumerated() {
                    let width = contentWidth * columns[c].1 - 4
                    let color: UIColor = c == 4 ? uiColor(r.value.category) : .black
                    (cell as NSString).draw(in: CGRect(x: x, y: y, width: width, height: rowHeight),
                                            withAttributes: [.font: c == 2 ? tableBold : tableFont, .foregroundColor: color])
                    x += contentWidth * columns[c].1
                }
                y += rowHeight
            }
        }
        try? data.write(to: url)
        return url
    }

    private static func drawFooter(page: Int) {
        let rect = CGRect(x: margin, y: pageHeight - margin - footerHeight + 8, width: contentWidth - 50, height: footerHeight)
        (disclaimer as NSString).draw(in: rect, withAttributes: [.font: smallFont, .foregroundColor: UIColor.gray])
        ("Page \(page)" as NSString).draw(at: CGPoint(x: pageWidth - margin - 40, y: rect.minY),
                                          withAttributes: [.font: smallFont, .foregroundColor: UIColor.gray])
    }

    private static func pair(_ avg: StatsEngine.Averages) -> String {
        "\(Int(avg.systolic.rounded()))/\(Int(avg.diastolic.rounded())) mmHg"
    }

    private static func signed(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
    }

    /// The light-mode AHA colors, since paper is always light.
    private static func uiColor(_ c: BPCategory) -> UIColor {
        UIColor(c.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }

    /// Daily averages as a print-friendly chart image.
    private static func renderChart(_ days: [ReadingValue]) -> UIImage? {
        let chart = Chart {
            RuleMark(y: .value("Systolic threshold", 130)).lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 3])).foregroundStyle(.orange)
            RuleMark(y: .value("Diastolic threshold", 80)).lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 3])).foregroundStyle(.orange)
            ForEach(days, id: \.date) { d in
                LineMark(x: .value("Date", d.date), y: .value("mmHg", d.systolic), series: .value("Type", "Systolic"))
                    .foregroundStyle(by: .value("Type", "Systolic"))
                PointMark(x: .value("Date", d.date), y: .value("mmHg", d.systolic))
                    .foregroundStyle(by: .value("Type", "Systolic")).symbolSize(16)
                LineMark(x: .value("Date", d.date), y: .value("mmHg", d.diastolic), series: .value("Type", "Diastolic"))
                    .foregroundStyle(by: .value("Type", "Diastolic"))
                PointMark(x: .value("Date", d.date), y: .value("mmHg", d.diastolic))
                    .foregroundStyle(by: .value("Type", "Diastolic")).symbolSize(16)
            }
        }
        .chartForegroundStyleScale(["Systolic": AppColors.systolic, "Diastolic": AppColors.diastolic])
        .chartYScale(domain: .automatic(includesZero: false))
        .chartLegend(position: .top, alignment: .leading)
        .frame(width: 516, height: 200)
        .padding(4)
        .background(Color.white)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: chart)
        renderer.scale = 3
        return renderer.uiImage
    }
}
