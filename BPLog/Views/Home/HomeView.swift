import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var showingAdd = false
    @State private var showingReport = false

    private var lastWeek: [ReadingValue] {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? .distantPast
        return readings.prefix { $0.date >= since }.map(\.value)
    }

    private var today: [ReadingValue] {
        let start = Calendar.current.startOfDay(for: Date())
        return readings.prefix { $0.date >= start }.map(\.value)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let last = readings.first {
                        if last.category == .crisis { CrisisBanner() }
                        latestCard(last)
                        averages
                    } else {
                        emptyCard
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Blood Pressure")
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Reading", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            .sheet(isPresented: $showingAdd) { AddReadingView() }
            .toolbar {
                if !readings.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingReport = true } label: { Label("Doctor Report", systemImage: "doc.text") }
                    }
                }
            }
            .sheet(isPresented: $showingReport) { ReportView() }
            // Widget "add" link: on a cold launch the flag is already set when Home appears.
            .onAppear(perform: openPendingAdd)
            .onChange(of: settings.pendingAddReading) { openPendingAdd() }
        }
    }

    private func openPendingAdd() {
        guard settings.pendingAddReading else { return }
        settings.pendingAddReading = false
        showingReport = false
        showingAdd = true
    }

    private func latestCard(_ r: Reading) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Latest reading").font(.headline).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(r.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                ReadingNumbers(systolic: r.systolic, diastolic: r.diastolic, pulse: r.pulse, size: 64)
                HStack {
                    CategoryBadge(category: r.category)
                    Spacer()
                    if r.source == .health {
                        Label("Apple Health", systemImage: "heart.text.square")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                CategoryScale(category: r.category)
                CategoryNote(category: r.category)
            }
        }
    }

    /// Today's average shows once there's more than one reading today — with one
    /// it would repeat the latest card. The 7-day average is a mean of daily
    /// averages, so a day with many readings counts once. Side by side when they
    /// fit, stacked at large text sizes.
    @ViewBuilder
    private var averages: some View {
        let today = self.today
        let week = lastWeek
        let days = StatsEngine.daily(week, calendar: .current)
        let todayCard = today.count > 1
            ? StatsEngine.averages(today).map { averageCard("Today", $0, footnote: "\(today.count) readings") }
            : nil
        let weekCard = StatsEngine.averages(days).map {
            averageCard("Last 7 days", $0, footnote: "\(week.count == 1 ? "1 reading" : "\(week.count) readings"), \(days.count == 1 ? "1 day" : "\(days.count) days")")
        }
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) { todayCard; weekCard }
            VStack(spacing: 12) { todayCard; weekCard }
        }
    }

    private func averageCard(_ title: String, _ avg: StatsEngine.Averages, footnote: String) -> some View {
        let sys = Int(avg.systolic.rounded())
        let dia = Int(avg.diastolic.rounded())
        let category = BPCategory.classify(systolic: sys, diastolic: dia)
        return CardView {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline).foregroundStyle(AppColors.textSecondary)
                Text("\(sys)/\(dia)")
                    .font(AppFont.number(34))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                HStack(spacing: 6) {
                    Circle().fill(category.color).frame(width: 8, height: 8)
                    Text(category.shortTitle).font(.subheadline.weight(.semibold)).foregroundStyle(category.color)
                }
                Text(footnote).font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var emptyCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.accent)
                Text("Track your blood pressure")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Text("Measure with your home monitor, then tap Add Reading. Your history, averages and charts build up from there.")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

/// Shown while the latest reading is in the crisis range. Points to care, never advises treatment.
struct CrisisBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("Readings this high need medical attention. Contact your doctor, or call 911 or your local emergency number if you have chest pain, shortness of breath, weakness, or trouble speaking.")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.crisisFill))
        .accessibilityElement(children: .combine)
    }
}
