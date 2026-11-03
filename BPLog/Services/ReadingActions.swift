import Foundation
import SwiftData

/// Deleting readings, shared by History's swipe, the edit screen's button and Settings.
enum ReadingActions {
    static func delete(_ readings: [Reading], context: ModelContext, settings: AppSettings) {
        remove(readings, context: context, settings: settings)
        for _ in readings { Analytics.track(.readingDeleted) }
    }

    /// Settings › Delete All Data: everyone's readings, then the people themselves,
    /// so a wrong backup can be undone by starting over and restoring the right one.
    static func deleteAll(context: ModelContext, settings: AppSettings) {
        remove((try? context.fetch(FetchDescriptor<Reading>())) ?? [], context: context, settings: settings)
        for person in settings.people { settings.removePerson(person.id) }
        Analytics.track(.dataDeleted)
    }

    private static func remove(_ readings: [Reading], context: ModelContext, settings: AppSettings) {
        for r in readings {
            // Remembered so a Health sync never brings the reading back.
            settings.rememberDeleted([r.id] + (r.healthKitID.map { [$0] } ?? []))
            // Our own writes leave Health too, whatever the sync toggle says now;
            // a cuff's sample stays the cuff's.
            if r.source == .manual, let id = r.healthKitID {
                let date = r.date
                Task { await HealthService.delete(healthKitID: id, date: date) }
            }
            context.delete(r)
        }
        try? context.save()
    }
}
