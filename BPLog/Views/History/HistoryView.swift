import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var editing: Reading?
    @State private var pendingDelete: Reading?
    @State private var searchText = ""
    @State private var scope = HistoryFilter.Scope.all
    @State private var showingFilter = false
    /// Days rendered so far; more load as the list nears its end. Building every
    /// day of a long history at once made the tab take ~1.5 s to open.
    @State private var visibleDays = HistoryView.pageSize
    static let pageSize = 60

    private var isFiltering: Bool { scope != .all || !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var filtered: [Reading] {
        let calendar = Calendar.current
        return readings.filter { r in
            HistoryFilter.isIn(scope, r.date, calendar: calendar)
                && HistoryFilter.matches(HistoryFilter.Item(value: r.value, tags: r.tags, note: r.note), query: searchText)
        }
    }



    private var days: [(day: Date, readings: [Reading])] {
        let calendar = Calendar.current
        return Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if readings.isEmpty {
                    ContentUnavailableView("No readings yet", systemImage: "list.bullet.rectangle",
                                           description: Text("Readings you add or import from Apple Health show up here."))
                } else if isFiltering && filtered.isEmpty {
                    ContentUnavailableView {
                        Label("No matching readings", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try another day or month, or search for a number, a tag or a word from a note.")
                    } actions: {
                        if scope != .all { Button("Show All Readings") { scope = .all } }
                    }
                } else {
                    let allDays = days
                    List {
                        ForEach(allDays.prefix(visibleDays), id: \.day) { day in
                            Section {
                                ForEach(day.readings) { r in
                                    Button { editing = r } label: { row(r) }
                                        .buttonStyle(.plain)
                                        // Long press: swipe-to-delete isn't obvious to everyone.
                                        .contextMenu {
                                            Button("Edit", systemImage: "pencil") { editing = r }
                                            // Explicit red: the app-wide blue tint otherwise colors the destructive icon.
                                            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = r }
                                                .tint(.red)
                                        }
                                }
                                .onDelete { offsets in delete(offsets.map { day.readings[$0] }) }
                            } header: {
                                dayHeader(day.day, day.readings)
                            }
                        }
                        if allDays.count > visibleDays {
                            // Reaching the end of what's shown loads the next page.
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                                .onAppear { visibleDays += Self.pageSize }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Number, tag or note")
            .onChange(of: scope) { visibleDays = Self.pageSize }
            .onChange(of: searchText) { visibleDays = Self.pageSize }
            .toolbar {
                if !readings.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { filterButton }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.bgApp)
            .sheet(item: $editing) { AddReadingView(editing: $0) }
            .confirmationDialog("Delete this reading?",
                                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete Reading", role: .destructive) {
                    if let r = pendingDelete { delete([r]) }
                    pendingDelete = nil
                }
            } message: {
                Text("It will be removed from your history. This can't be undone.")
            }
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

    /// Shows the current scope; opens the All / Month / Day picker.
    private var filterButton: some View {
        Button {
            showingFilter = true
        } label: {
            Label(scopeTitle, systemImage: scope == .all ? "calendar" : "calendar.badge.checkmark")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("Filter by date, \(scopeTitle)")
        // Month counts are worked out only when the sheet opens.
        .sheet(isPresented: $showingFilter) {
            HistoryFilterSheet(scope: $scope, months: HistoryFilter.monthCounts(readings.map(\.date), calendar: .current))
        }
    }

    private var scopeTitle: String {
        switch scope {
        case .all: "All"
        case .month(let m): m.formatted(.dateTime.month(.abbreviated).year())
        case .day(let d): d.formatted(date: .abbreviated, time: .omitted)
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
        ReadingActions.delete(items, context: context, settings: settings)
    }
}
