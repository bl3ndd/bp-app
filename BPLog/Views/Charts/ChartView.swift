import SwiftUI
import SwiftData
import Charts

enum ChartRange: String, CaseIterable, Identifiable {
    case week = "7D", month = "30D", quarter = "90D", year = "1Y", all = "All"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        case .all: nil
        }
    }

    /// The last `days` days up to `now`; nil for All (no lower bound).
    func interval(now: Date) -> DateInterval? {
        guard let days else { return nil }
        return DateInterval(start: now.addingTimeInterval(-Double(days) * 86_400), end: now)
    }

    /// The same-length period right before `interval(now:)`, for "vs previous" deltas.
    func previousInterval(now: Date) -> DateInterval? {
        guard let current = interval(now: now) else { return nil }
        return DateInterval(start: current.start.addingTimeInterval(-current.duration), end: current.start)
    }
}

struct ChartView: View {
    @Environment(PurchaseService.self) private var purchases
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Reading.date) private var allReadings: [Reading]

    /// The person picked in the toolbar; `allReadings` holds everyone's.
    private var readings: [Reading] { allReadings.of(settings.activePersonID) }
    @State private var range = ChartRange.month
    @State private var showingPaywall = false
    @State private var showPulse = false
    /// Off by default: points are averaged per day, week or month (by span),
    /// since raw readings turn a long chart into a solid band.
    @State private var showEveryReading = false

    private struct Point: Identifiable {
        /// Position in the list: two readings can share a timestamp.
        var id = 0
        let date: Date
        let systolic: Double
        let diastolic: Double
        let pulse: Double?
    }

    private var values: [ReadingValue] {
        guard let days = range.days, let since = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return readings.map(\.value)
        }
        return readings.filter { $0.date >= since }.map(\.value)
    }

    /// Span of what's shown, in days: the range itself, or the history's length for All.
    private var bucket: StatsEngine.ChartBucket {
        let span = range.days ?? values.first.map { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0 } ?? 0
        return .forSpan(days: span)
    }

    private var points: [Point] {
        let raw: [Point]
        if !showEveryReading {
            raw = StatsEngine.periodAverages(values, by: bucket.component, calendar: .current)
                .map { Point(date: $0.day, systolic: $0.averages.systolic, diastolic: $0.averages.diastolic, pulse: $0.averages.pulse) }
        } else {
            raw = values.map { Point(date: $0.date, systolic: Double($0.systolic), diastolic: Double($0.diastolic), pulse: $0.pulse.map(Double.init)) }
        }
        return raw.enumerated().map { i, p in var p = p; p.id = i; return p }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SegmentedChips(options: ChartRange.allCases, selection: $range) { $0.rawValue }
                    .onChange(of: range) { old, new in
                        // A locked range snaps back and opens the paywall instead.
                        if let feature = new.feature, ProFeature.isLocked(feature, isPro: purchases.isPro) {
                            range = old
                            showingPaywall = true
                        }
                    }
                    if !purchases.isPro {
                        HStack(spacing: 8) {
                            ProMark()
                            Text("90 days, 1 year and all-time charts")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                        }
                    }

                    CardView {
                        if points.isEmpty {
                            ContentUnavailableView("No readings in this period", systemImage: "chart.xyaxis.line")
                                .frame(height: 280)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                chart.frame(height: 300)
                                Text(showEveryReading ? "Every reading" : bucket.label)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }

                    CardView {
                        VStack(spacing: 4) {
                            Toggle("Show pulse", isOn: $showPulse)
                            Divider()
                            Toggle("Show every reading", isOn: $showEveryReading)
                        }
                        .font(.body.weight(.medium))
                        .tint(AppColors.accent)
                    }

                    if let avg = StatsEngine.averages(values) {
                        let sys = Int(avg.systolic.rounded())
                        let dia = Int(avg.diastolic.rounded())
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Average for this period").font(.headline).foregroundStyle(AppColors.textSecondary)
                                ReadingNumbers(systolic: sys, diastolic: dia, pulse: avg.pulse.map { Int($0.rounded()) }, size: 40)
                                CategoryBadge(category: .classify(systolic: sys, diastolic: dia))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Charts")
            .toolbar { PersonPicker() }
            .sheet(isPresented: $showingPaywall) { PaywallView(source: "charts") }
        }
    }

    private var chart: some View {
        Chart {
            // AHA thresholds: under 120/80 is normal, 130/80 starts Stage 1.
            RuleMark(y: .value("Systolic threshold", 130))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(AppColors.stage1.opacity(0.6))
                .annotation(position: .top, alignment: .leading) {
                    Text("130").font(.caption).foregroundStyle(AppColors.stage1)
                }
            RuleMark(y: .value("Diastolic threshold", 80))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(AppColors.stage1.opacity(0.6))
                .annotation(position: .top, alignment: .leading) {
                    Text("80").font(.caption).foregroundStyle(AppColors.stage1)
                }
            // Dots only while they can be told apart; beyond that the line says it.
            let showDots = points.count <= 60
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("mmHg", p.systolic), series: .value("Type", "Systolic"))
                    .foregroundStyle(by: .value("Type", "Systolic"))
                if showDots {
                    PointMark(x: .value("Date", p.date), y: .value("mmHg", p.systolic))
                        .foregroundStyle(by: .value("Type", "Systolic"))
                        .symbolSize(12)
                }
                LineMark(x: .value("Date", p.date), y: .value("mmHg", p.diastolic), series: .value("Type", "Diastolic"))
                    .foregroundStyle(by: .value("Type", "Diastolic"))
                if showDots {
                    PointMark(x: .value("Date", p.date), y: .value("mmHg", p.diastolic))
                        .foregroundStyle(by: .value("Type", "Diastolic"))
                        .symbolSize(12)
                }
                if showPulse, let pulse = p.pulse {
                    LineMark(x: .value("Date", p.date), y: .value("bpm", pulse), series: .value("Type", "Pulse"))
                        .foregroundStyle(by: .value("Type", "Pulse"))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
            }
        }
        .chartForegroundStyleScale(["Systolic": AppColors.systolic, "Diastolic": AppColors.diastolic, "Pulse": AppColors.pulse])
        .chartYScale(domain: .automatic(includesZero: false))
        .chartLegend(position: .top, alignment: .leading)
    }
}
