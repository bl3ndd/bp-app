import SwiftUI
import SwiftData

/// Three short steps: what the app is (and isn't), Apple Health, reminders.
/// Health and reminders are skippable — nothing in the app requires them (guideline 5.1.2(i)).
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var morningOn = true
    @State private var eveningOn = true
    @State private var morning = ReminderTime.date(fromMinutes: NotificationService.defaultMorning)
    @State private var evening = ReminderTime.date(fromMinutes: NotificationService.defaultEvening)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case 0: welcome
                    case 1: health
                    default: reminders
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 12) {
                Button(primaryTitle, action: primary).buttonStyle(PrimaryButtonStyle())
                if step > 0 {
                    Button(step == 1 ? "Not Now" : "Skip", action: next)
                        .font(.body.weight(.medium))
                        .frame(minHeight: 44)
                }
            }
            .padding(24)
        }
        .background(AppColors.bgApp)
        .animation(.default, value: step)
    }

    // MARK: Steps

    private var welcome: some View {
        Group {
            header("heart.text.square.fill", "Track your blood pressure")
            bullet("square.and.pencil", "Log readings from your home monitor in seconds.")
            bullet("chart.xyaxis.line", "See your averages, trends and charts.")
            bullet("doc.richtext", "Share a doctor-ready report.")
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill").font(.title2).foregroundStyle(AppColors.accent)
                Text("Simply BP is not a medical device and doesn't measure blood pressure. Always check with your doctor before making medical decisions.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent.opacity(0.12)))
        }
    }

    private var health: some View {
        Group {
            header("heart.fill", "Connect Apple Health")
            Text("Readings you add are saved to Apple Health, and readings from a smart blood pressure monitor show up here automatically.")
                .font(.title3)
                .foregroundStyle(AppColors.textSecondary)
            bullet("arrow.triangle.2.circlepath", "Apple Health keeps your history in sync across your devices.")
            bullet("lock.fill", "Your data stays on your devices. We never see it.")
        }
    }

    private var reminders: some View {
        Group {
            header("bell.fill", "Daily reminders")
            Text("Doctors usually ask for readings in the morning and in the evening. We'll remind you.")
                .font(.title3)
                .foregroundStyle(AppColors.textSecondary)
            CardView {
                VStack(spacing: 12) {
                    reminderRow("Morning", isOn: $morningOn, time: $morning, range: 0...(12 * 60 - 1))
                    Divider()
                    reminderRow("Evening", isOn: $eveningOn, time: $evening, range: (12 * 60)...(24 * 60 - 1))
                }
            }
        }
    }

    // MARK: Pieces

    private func header(_ icon: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon).font(.system(size: 52)).foregroundStyle(AppColors.accent)
            Text(title).font(.largeTitle.bold()).foregroundStyle(AppColors.textPrimary)
        }
        .padding(.top, 24)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(AppColors.accent).frame(width: 32)
            Text(text).font(.title3).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// `range` is minutes since midnight: morning stays before noon, evening after.
    private func reminderRow(_ title: String, isOn: Binding<Bool>, time: Binding<Date>, range: ClosedRange<Int>) -> some View {
        HStack {
            Toggle(title, isOn: isOn).font(.title3.weight(.medium)).tint(AppColors.accent)
            if isOn.wrappedValue {
                DatePicker(title, selection: time,
                           in: ReminderTime.date(fromMinutes: range.lowerBound)...ReminderTime.date(fromMinutes: range.upperBound),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
    }

    // MARK: Actions

    private var primaryTitle: String {
        switch step {
        case 0: "Get Started"
        case 1: "Connect Apple Health"
        default: "Turn On Reminders"
        }
    }

    private func primary() {
        switch step {
        case 0:
            next()
        case 1:
            Task {
                if await HealthService.requestAuthorization() {
                    settings.healthEnabled = true
                    await HealthService.importNew(into: context, deletedIDs: settings.deletedIDs)
                    await HealthService.backfill(context)
                }
                next()
            }
        default:
            Task {
                let minutes = [morningOn ? ReminderTime.minutes(from: morning) : nil,
                               eveningOn ? ReminderTime.minutes(from: evening) : nil].compactMap { $0 }
                if !minutes.isEmpty, await NotificationService.requestPermission() {
                    settings.reminderMinutes = minutes
                    NotificationService.schedule(minutes: minutes)
                }
                next()
            }
        }
    }

    private func next() {
        if step < 2 {
            step += 1
            Analytics.track(.onboardingStep, ["step": String(step + 1)])
        } else {
            Analytics.track(.onboardingCompleted, ["health": settings.healthEnabled ? "on" : "off",
                                                   "reminders": settings.reminderMinutes.isEmpty ? "off" : "on"])
            settings.hasCompletedOnboarding = true
        }
    }
}
