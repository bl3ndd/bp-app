import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var showingAdd = false
    @State private var showingReport = false

    private var lastWeek: [ReadingValue] {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return readings.prefix { $0.date >= since }.map(\.value)
    }

    private var today: [ReadingValue] {
        let start = Calendar.current.startOfDay(for: Date())
        return readings.prefix { $0.date >= start }.map(\.value)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let last = readings.first {
                        if last.category == .crisis { CrisisBanner() }
                        latestCard(last)
                        todayCard
                        weekCard
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
        }
    }

    private func latestCard(_ r: Reading) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Latest reading").font(.headline).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if r.source == .health {
                        Label("Apple Health", systemImage: "heart.text.square")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                ReadingNumbers(systolic: r.systolic, diastolic: r.diastolic, pulse: r.pulse)
                HStack {
                    CategoryBadge(category: r.category)
                    Spacer()
                    Text(r.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                CategoryNote(category: r.category)
            }
        }
    }

    /// Only once there's more than one reading today — with one, it would just repeat the latest card.
    @ViewBuilder
    private var todayCard: some View {
        let today = self.today
        if today.count > 1, let avg = StatsEngine.averages(today) {
            averageCard("Today's average", avg, footnote: "\(today.count) readings today")
        }
    }

    /// Mean of daily averages, so a day with many readings counts once.
    @ViewBuilder
    private var weekCard: some View {
        let week = lastWeek
        let days = StatsEngine.daily(week, calendar: .current)
        if let avg = StatsEngine.averages(days) {
            averageCard("Your 7-day average", avg,
                        footnote: "\(week.count == 1 ? "1 reading" : "\(week.count) readings"), \(days.count == 1 ? "1 day" : "\(days.count) days")")
        }
    }

    private func averageCard(_ title: String, _ avg: StatsEngine.Averages, footnote: String) -> some View {
        let sys = Int(avg.systolic.rounded())
        let dia = Int(avg.diastolic.rounded())
        return CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline).foregroundStyle(AppColors.textSecondary)
                ReadingNumbers(systolic: sys, diastolic: dia, pulse: avg.pulse.map { Int($0.rounded()) }, size: 40)
                HStack {
                    CategoryBadge(category: .classify(systolic: sys, diastolic: dia))
                    Spacer()
                    Text(footnote)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
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
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.crisis))
        .accessibilityElement(children: .combine)
    }
}
