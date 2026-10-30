import SwiftUI
import SwiftData
import Charts

/// Pro statistics. Free users see the real layout blurred under an unlock
/// prompt — what they'd get, without the numbers.
struct StatsView: View {
    @Environment(PurchaseService.self) private var purchases
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Reading.date) private var readings: [Reading]
    @State private var range = ChartRange.month
    @State private var showingPaywall = false
    @State private var showingReport = false

    private var locked: Bool { ProFeature.isLocked(.fullStats, isPro: purchases.isPro) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $range) {
                        ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if readings.isEmpty {
                        ContentUnavailableView("No readings yet", systemImage: "chart.bar.xaxis",
                                               description: Text("Add a few readings and your statistics show up here."))
                    } else {
                        ZStack(alignment: .top) {
                            StatsContent(all: readings.map(\.value), range: range,
                                         targetSystolic: settings.targetSystolic, targetDiastolic: settings.targetDiastolic)
                                .blur(radius: locked ? 8 : 0)
                                .allowsHitTesting(!locked)
                                .accessibilityHidden(locked)
                            if locked { unlockCard.padding(.top, 40) }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Statistics")
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .toolbar {
                if !readings.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingReport = true } label: { Label("Doctor Report", systemImage: "doc.text") }
                    }
                }
            }
            .sheet(isPresented: $showingReport) { ReportView() }
        }
    }

    private var unlockCard: some View {
        CardView {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill").font(.title).foregroundStyle(AppColors.accent)
                Text("Full statistics are part of Pro")
                    .font(.title3.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Text("Trends, morning vs. evening, time in range and more — from your own readings.")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Unlock Pro") { showingPaywall = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct StatsContent: View {
    let all: [ReadingValue]
    let range: ChartRange
    let targetSystolic: Int
    let targetDiastolic: Int

    private let calendar = Calendar.current
    private let now = Date()

    private var values: [ReadingValue] {
        range.interval(now: now).map { StatsEngine.readings(all, in: $0) } ?? all
    }

    private var previous: [ReadingValue] {
        range.previousInterval(now: now).map { StatsEngine.readings(all, in: $0) } ?? []
    }

    /// Day-level numbers use one averaged reading per day, so a day with many
    /// readings doesn't outweigh the rest. Extremes and morning/evening stay on
    /// the raw readings — there the individual values are the point.
    private var days: [ReadingValue] { StatsEngine.daily(values, calendar: calendar) }

    var body: some View {
        let days = self.days
        VStack(spacing: 16) {
            if let avg = StatsEngine.averages(days) {
                averageCard(avg, readings: values.count, days: days)
                trendCard(days)
                extremesCard
                categoryCard(days)
                if let share = StatsEngine.timeInRange(days, systolicBelow: targetSystolic, diastolicBelow: targetDiastolic) {
                    inRangeCard(share)
                }
                morningEveningCard
                weekdayCard(days)
                pressureCard(days)
                streakCard
            } else {
                ContentUnavailableView("No readings in this period", systemImage: "calendar")
            }
        }
    }

    // MARK: Cards

    private func averageCard(_ avg: StatsEngine.Averages, readings: Int, days: [ReadingValue]) -> some View {
        let sys = Int(avg.systolic.rounded())
        let dia = Int(avg.diastolic.rounded())
        return CardView {
            VStack(alignment: .leading, spacing: 10) {
                title("Average")
                ReadingNumbers(systolic: sys, diastolic: dia, pulse: avg.pulse.map { Int($0.rounded()) }, size: 44)
                HStack {
                    CategoryBadge(category: .classify(systolic: sys, diastolic: dia))
                    Spacer()
                    caption("\(readings == 1 ? "1 reading" : "\(readings) readings"), \(days.count == 1 ? "1 day" : "\(days.count) days")")
                }
                caption("Each day counts once: several readings on the same day are averaged first.")
                if let delta = StatsEngine.periodComparison(current: days, previous: StatsEngine.daily(previous, calendar: calendar)) {
                    Text("vs. previous \(range.rawValue): \(signed(delta.systolic))/\(signed(delta.diastolic)) mmHg")
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    private func trendCard(_ days: [ReadingValue]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                title("Trend")
                if let trend = StatsEngine.trend(days) {
                    Text("\(signed(trend.systolicPerWeek, digits: 1))/\(signed(trend.diastolicPerWeek, digits: 1)) mmHg per week")
                        .font(AppFont.number(26))
                        .foregroundStyle(AppColors.textPrimary)
                    caption(trend.systolicPerWeek < -0.5 ? "Your top number is going down."
                            : trend.systolicPerWeek > 0.5 ? "Your top number is going up."
                            : "Your readings are holding steady.")
                } else {
                    caption("Needs readings on at least \(StatsEngine.trendMinReadings) different days, spread over a week or more.")
                }
            }
        }
    }

    @ViewBuilder
    private var extremesCard: some View {
        if let e = StatsEngine.extremes(values) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    title("Highest and lowest")
                    extremeRow("Highest", e.highest)
                    Divider()
                    extremeRow("Lowest", e.lowest)
                }
            }
        }
    }

    private func extremeRow(_ label: String, _ r: ReadingValue) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.headline).foregroundStyle(AppColors.textPrimary)
                caption(r.date.formatted(date: .abbreviated, time: .shortened))
            }
            Spacer()
            Text("\(r.systolic)/\(r.diastolic)")
                .font(AppFont.number(26))
                .foregroundStyle(r.category.color)
        }
    }

    private func categoryCard(_ days: [ReadingValue]) -> some View {
        let distribution = StatsEngine.categoryDistribution(days)
        let total = Double(days.count)
        let present = BPCategory.allCases.filter { distribution[$0] != nil }
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                title("Days by category")
                Chart(present, id: \.self) { c in
                    BarMark(x: .value("Share", Double(distribution[c] ?? 0) / total), stacking: .normalized)
                        .foregroundStyle(c.color)
                }
                .chartXAxis(.hidden)
                .frame(height: 28)
                ForEach(present, id: \.self) { c in
                    HStack {
                        Circle().fill(c.color).frame(width: 12, height: 12)
                        Text(c.title).font(.body).foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text("\(Int((Double(distribution[c] ?? 0) / total * 100).rounded()))%")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    private func inRangeCard(_ share: Double) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                title("In your target range")
                Text("\(Int((share * 100).rounded()))%")
                    .font(AppFont.number(40))
                    .foregroundStyle(AppColors.normal)
                ProgressView(value: share).tint(AppColors.normal)
                caption("Days with an average below \(targetSystolic)/\(targetDiastolic). You can change the target in Settings.")
            }
        }
    }

    private var morningEveningCard: some View {
        let split = StatsEngine.morningVsEvening(values, calendar: calendar)
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                title("Morning vs. evening")
                HStack(spacing: 12) {
                    partOfDay("Morning", "sunrise.fill", "before noon", split.morning)
                    partOfDay("Evening", "moon.fill", "after 6 PM", split.evening)
                }
            }
        }
    }

    private func partOfDay(_ name: String, _ icon: String, _ hint: String, _ avg: StatsEngine.Averages?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(name, systemImage: icon).font(.headline).foregroundStyle(AppColors.textPrimary)
            if let avg {
                Text("\(Int(avg.systolic.rounded()))/\(Int(avg.diastolic.rounded()))")
                    .font(AppFont.number(28))
                    .foregroundStyle(AppColors.textPrimary)
            } else {
                Text("—").font(AppFont.number(28)).foregroundStyle(AppColors.textSecondary)
            }
            caption(hint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.bgInput))
    }

    private func weekdayCard(_ days: [ReadingValue]) -> some View {
        let byDay = StatsEngine.weekdayAverages(days, calendar: calendar)
        let symbols = calendar.shortWeekdaySymbols
        // Start the week where the user's calendar does (Sunday in the US).
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                title("Average by day of week")
                Chart(order, id: \.self) { day in
                    if let avg = byDay[day] {
                        BarMark(x: .value("Day", symbols[day - 1]), y: .value("Systolic", avg.systolic))
                            .foregroundStyle(AppColors.systolic)
                        BarMark(x: .value("Day", symbols[day - 1]), y: .value("Diastolic", avg.diastolic))
                            .foregroundStyle(AppColors.diastolic)
                    }
                }
                .chartXScale(domain: order.map { symbols[$0 - 1] })
                .frame(height: 180)
                caption("Dark bars: top number. Light bars: bottom number.")
            }
        }
    }

    private func pressureCard(_ days: [ReadingValue]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                title("More numbers")
                if let pp = StatsEngine.pulsePressure(days) {
                    metric("Pulse pressure", "\(Int(pp.rounded())) mmHg", "The gap between your top and bottom numbers.")
                }
                Divider()
                if let map = StatsEngine.meanArterialPressure(days) {
                    metric("Mean arterial pressure", "\(Int(map.rounded())) mmHg", "The average pressure in your arteries during one heartbeat.")
                }
            }
        }
    }

    private var streakCard: some View {
        let streak = StatsEngine.streak(all, today: now, calendar: calendar)
        return CardView {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill").font(.largeTitle).foregroundStyle(AppColors.stage1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(streak == 1 ? "1 day in a row" : "\(streak) days in a row")
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.textPrimary)
                    caption("Days in a row with at least one reading.")
                }
            }
        }
    }

    // MARK: Pieces

    private func metric(_ name: String, _ value: String, _ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(value).font(AppFont.number(22)).foregroundStyle(AppColors.textPrimary)
            }
            caption(explanation)
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.headline).foregroundStyle(AppColors.textSecondary)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func signed(_ value: Double, digits: Int = 0) -> String {
        let text = value.formatted(.number.precision(.fractionLength(digits)).sign(strategy: .always(includingZero: false)))
        return text
    }
}
