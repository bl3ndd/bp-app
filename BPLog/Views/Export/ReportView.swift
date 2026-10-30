import SwiftUI
import SwiftData
import QuickLook

/// Doctor PDF report (Pro): pick a period, optionally a name, preview and share.
struct ReportView: View {
    @Environment(PurchaseService.self) private var purchases
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Reading.date) private var readings: [Reading]

    @State private var range = ChartRange.month
    @AppStorage("reportName") private var name = ""
    @State private var pdf: URL?
    @State private var showingPaywall = false

    private var selected: [Reading] {
        guard let interval = range.interval(now: Date()) else { return readings }
        return readings.filter { interval.contains($0.date) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Period", selection: $range) {
                        ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Readings in this period", value: "\(selected.count)")
                } footer: {
                    Text("Your doctor gets a one-page summary built on daily averages, a chart, and a table of every reading.")
                }
                Section {
                    TextField("Your name (optional)", text: $name)
                        .textContentType(.name)
                } footer: {
                    Text("Shown at the top of the report.")
                }
            }
            .navigationTitle("Doctor Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: create) {
                    HStack(spacing: 8) {
                        Text("Create PDF Report")
                        if !purchases.isPro { Image(systemName: "lock.fill") }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected.isEmpty)
                .padding()
                .background(.bar)
            }
            .quickLookPreview($pdf)
            .sheet(isPresented: $showingPaywall) { PaywallView(source: "report") }
        }
    }

    private func create() {
        guard !ProFeature.isLocked(.pdfReport, isPro: purchases.isPro) else {
            showingPaywall = true
            return
        }
        Analytics.track(.reportCreated, ["range": range.rawValue])
        pdf = PDFGenerator.generate(readings: selected.map { ReportReading($0) }, interval: range.interval(now: Date()),
                                    patientName: name, targetSystolic: settings.targetSystolic, targetDiastolic: settings.targetDiastolic)
    }
}
