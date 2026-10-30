import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(PurchaseService.self) private var purchases
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Reading.date) private var readings: [Reading]

    @State private var backup: BackupDocument?
    @State private var showImporter = false
    @State private var message: String?
    @State private var syncing = false

    var body: some View {
        NavigationStack {
            Form {
                if HealthService.isAvailable {
                    Section {
                        Toggle("Sync with Apple Health", isOn: Binding(
                            get: { settings.healthEnabled },
                            set: { on in Task { await setHealth(on) } }
                        ))
                        .tint(AppColors.accent)
                        if settings.healthEnabled {
                            Button {
                                Task { await syncNow() }
                            } label: {
                                if syncing {
                                    HStack { ProgressView(); Text("Syncing…") }
                                } else {
                                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                            .disabled(syncing)
                        }
                    } header: {
                        Text("Apple Health")
                    } footer: {
                        Text("Readings you add are saved to Apple Health, and readings from your smart monitor show up here. Apple Health keeps them in sync across your devices: on a new iPhone, turn this on and your history comes back.")
                    }
                }

                Section {
                    reminderRow("Morning reminder", morning: true)
                    reminderRow("Evening reminder", morning: false)
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Doctors usually ask for readings in the morning and in the evening.")
                }

                @Bindable var settings = settings
                Section {
                    Stepper("Top number below \(settings.targetSystolic)", value: $settings.targetSystolic, in: 100...160, step: 5)
                    Stepper("Bottom number below \(settings.targetDiastolic)", value: $settings.targetDiastolic, in: 60...100, step: 5)
                } header: {
                    Text("Your target")
                } footer: {
                    Text("Used for \"In your target range\" in Statistics and the doctor report. 130/80 is a common goal; ask your doctor what yours is.")
                }

                Section {
                    Button {
                        prepareBackup()
                    } label: {
                        Label("Back Up Readings", systemImage: "square.and.arrow.up")
                    }
                    .disabled(readings.isEmpty)
                    Button {
                        showImporter = true
                    } label: {
                        Label("Restore from Backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Saves all your readings to a file, wherever you choose. Restoring only adds readings you don't already have — nothing gets deleted.")
                }

                Section("Purchases") {
                    if purchases.isPro {
                        Label("Simply BP Pro is unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(AppColors.normal)
                    }
                    Button("Restore Purchases") {
                        Task { await purchases.restore() }
                    }
                    .disabled(purchases.isWorking)
                }

                Section {
                    Toggle("Share anonymous usage stats", isOn: $settings.analyticsEnabled)
                        .tint(AppColors.accent)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Counts which features get used, so we know what to improve. Never your readings, Health data or anything you type.")
                }

                Section("About") {
                    Link(destination: AppLinks.privacyPolicy) { Label("Privacy Policy", systemImage: "hand.raised.fill") }
                    Link(destination: AppLinks.support) { Label("Contact Support", systemImage: "envelope.fill") }
                    Text("Simply BP is not a medical device and does not measure blood pressure. It records the readings you take with your own monitor. Always check with your doctor before making medical decisions.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("High blood pressure categories follow the 2017 ACC/AHA guideline. \"Low\" marks readings below 90/60, a commonly used threshold.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: Binding(get: { backup != nil }, set: { if !$0 { backup = nil } }),
                document: backup,
                contentType: .json,
                defaultFilename: BackupService.filename()
            ) { result in
                if case .failure = result { message = "The backup couldn't be saved. Please try again." }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                restore(result)
            }
            .alert("Simply BP", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    // MARK: Reminders

    /// One toggle + time per slot; the stored list keeps at most one morning and one evening time.
    @ViewBuilder
    private func reminderRow(_ title: String, morning: Bool) -> some View {
        let current = settings.reminderMinutes.first { ReminderTime.isMorning($0) == morning }
        Toggle(title, isOn: Binding(
            get: { current != nil },
            set: { on in
                let defaultTime = morning ? NotificationService.defaultMorning : NotificationService.defaultEvening
                Task { await setReminder(morning: morning, to: on ? (current ?? defaultTime) : nil) }
            }
        ))
        .tint(AppColors.accent)
        if let current {
            DatePicker("Time", selection: Binding(
                get: { ReminderTime.date(fromMinutes: current) },
                set: { date in
                    let minutes = ReminderTime.minutes(from: date)
                    // A time picked on the other side of noon would jump slots; keep it in this one.
                    guard ReminderTime.isMorning(minutes) == morning else { return }
                    Task { await setReminder(morning: morning, to: minutes) }
                }
            ), displayedComponents: .hourAndMinute)
        }
    }

    private func setReminder(morning: Bool, to minutes: Int?) async {
        if minutes != nil, !(await NotificationService.requestPermission()) {
            message = "Notifications are off for Simply BP. Turn them on in the Settings app to get reminders."
            return
        }
        var list = settings.reminderMinutes.filter { ReminderTime.isMorning($0) != morning }
        if let minutes { list.append(minutes) }
        settings.reminderMinutes = list.sorted()
        NotificationService.schedule(minutes: settings.reminderMinutes)
        Analytics.track(.remindersChanged, ["count": String(settings.reminderMinutes.count)])
    }

    // MARK: Health

    private func setHealth(_ on: Bool) async {
        guard on else {
            settings.healthEnabled = false
            return
        }
        guard await HealthService.requestAuthorization() else {
            message = "Apple Health isn't available right now. Please try again."
            return
        }
        settings.healthEnabled = true
        Analytics.track(.healthEnabled, ["from": "settings"])
        await syncNow()
    }

    /// Pull first, so readings synced from another device aren't written back as duplicates.
    private func syncNow() async {
        syncing = true
        let imported = await HealthService.importNew(into: context)
        let saved = await HealthService.backfill(context)
        syncing = false
        Analytics.track(.healthSynced)
        message = "Brought in \(imported) readings from Apple Health and saved \(saved) to it. If nothing moved, check Settings › Health › Data Access & Devices › Simply BP and allow blood pressure and heart rate."
    }

    private func prepareBackup() {
        do {
            backup = BackupDocument(data: try BackupService.export(readings))
            Analytics.track(.backupSaved)
        } catch {
            message = "The backup couldn't be created. Please try again."
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        // The picker hands back a URL outside the sandbox; reading it needs scoped access.
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        do {
            let outcome = try BackupService.restore(from: try Data(contentsOf: url), into: context)
            Analytics.track(.backupRestored)
            message = "Added \(outcome.added) readings. Skipped \(outcome.skipped) you already had."
        } catch {
            message = "This file doesn't look like a Simply BP backup."
        }
    }
}
