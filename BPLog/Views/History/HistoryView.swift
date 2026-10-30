import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var editing: Reading?

    private var days: [(day: Date, readings: [Reading])] {
        let calendar = Calendar.current
        return Dictionary(grouping: readings) { calendar.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if readings.isEmpty {
                    ContentUnavailableView("No readings yet", systemImage: "list.bullet.rectangle",
                                           description: Text("Readings you add or import from Apple Health show up here."))
                } else {
                    List {
                        ForEach(days, id: \.day) { day in
                            Section {
                                ForEach(day.readings) { r in
                                    Button { editing = r } label: { row(r) }
                                        .buttonStyle(.plain)
                                }
                                .onDelete { offsets in delete(offsets.map { day.readings[$0] }) }
                            } header: {
                                dayHeader(day.day, day.readings)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $editing) { AddReadingView(editing: $0) }
        }
    }

    /// Date, plus the day's average when there's more than one reading to average.
    private func dayHeader(_ day: Date, _ readings: [Reading]) -> some View {
        HStack {
            Text(day.formatted(date: .complete, time: .omitted))
            Spacer()
            if readings.count > 1, let avg = StatsEngine.averages(readings.map(\.value)) {
                let sys = Int(avg.systolic.rounded())
                let dia = Int(avg.diastolic.rounded())
                Text("avg \(sys)/\(dia)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BPCategory.classify(systolic: sys, diastolic: dia).color)
            }
        }
    }

    private func row(_ r: Reading) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(r.category.color)
                .frame(width: 5, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(r.systolic)/\(r.diastolic)")
                    .font(AppFont.number(26))
                    .foregroundStyle(AppColors.textPrimary)
                Text(r.category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(r.category.color)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(r.date.formatted(date: .omitted, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 6) {
                    if r.source == .health {
                        Image(systemName: "heart.text.square").accessibilityLabel("From Apple Health")
                    }
                    if let pulse = r.pulse { Text("\(pulse) bpm") }
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func delete(_ items: [Reading]) {
        for r in items {
            // Only our own writes are removed from Health; a cuff's data stays the cuff's.
            if settings.healthEnabled, r.source == .manual, let id = r.healthKitID {
                let date = r.date
                Task { await HealthService.delete(healthKitID: id, date: date) }
            }
            context.delete(r)
            Analytics.track(.readingDeleted)
        }
        try? context.save()
    }
}
