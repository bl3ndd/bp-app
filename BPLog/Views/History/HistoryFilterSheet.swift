import SwiftUI

/// Pick what History shows: everything, one month, or one day.
struct HistoryFilterSheet: View {
    @Binding var scope: HistoryFilter.Scope
    /// First day of each month that has readings, newest first, with its count.
    let months: [(month: Date, count: Int)]

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .all
    @State private var day = Date()

    enum Mode: String, CaseIterable { case all = "All", month = "Month", day = "Day" }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                SegmentedChips(options: Mode.allCases, selection: $mode) { $0.rawValue }
                    .padding(.horizontal)
                switch mode {
                case .all:
                    Text("Every reading, newest first.")
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal)
                    Spacer()
                case .month:
                    List(months, id: \.month) { item in
                        Button {
                            scope = .month(item.month)
                            dismiss()
                        } label: {
                            HStack {
                                Text(item.month.formatted(.dateTime.month(.wide).year()))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Text(item.count == 1 ? "1 reading" : "\(item.count) readings")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                                if case .month(let m) = scope, m == item.month {
                                    Image(systemName: "checkmark").foregroundStyle(AppColors.accent)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .scrollContentBackground(.hidden)
                case .day:
                    DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppColors.accent)
                        .padding(.horizontal)
                    Spacer()
                }
            }
            .padding(.top)
            .background(AppColors.bgApp)
            .navigationTitle("Show readings for")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if mode != .month {
                    Button(mode == .all ? "Show All Readings" : "Show \(day.formatted(date: .abbreviated, time: .omitted))") {
                        scope = mode == .all ? .all : .day(day)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding()
                }
            }
            .onAppear {
                switch scope {
                case .all: mode = .all
                case .month: mode = .month
                case .day(let d): mode = .day; day = d
                }
            }
        }
        .presentationDetents([.large])
    }
}
