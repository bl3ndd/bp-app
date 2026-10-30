import Foundation
import SwiftData

/// Deleting readings, shared by History's swipe and the edit screen's button.
enum ReadingActions {
    static func delete(_ readings: [Reading], context: ModelContext, settings: AppSettings) {
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
            Analytics.track(.readingDeleted)
        }
        try? context.save()
    }
}
