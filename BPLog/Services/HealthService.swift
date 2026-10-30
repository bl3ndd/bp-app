import Foundation
import HealthKit
import SwiftData

/// A blood pressure correlation as read from Health.
nonisolated struct HealthReading: Equatable, Sendable {
    var id: UUID
    var date: Date
    var systolic: Int
    var diastolic: Int
    var pulse: Int?
    var sourceBundleID: String
    var meta = HealthMeta()
}

/// Everything about a reading beyond the numbers, carried in the correlation's
/// metadata. Health syncs it across the user's devices, so a fresh install
/// gets back tags and notes too, not just the numbers.
nonisolated struct HealthMeta: Equatable, Sendable {
    var readingID: UUID?
    var arm: String?
    var position: String?
    var tags: [String] = []
    var note = ""

    private static let armKey = "BPLogArm"
    private static let positionKey = "BPLogPosition"
    private static let tagsKey = "BPLogTags"
    private static let noteKey = "BPLogNote"

    init(readingID: UUID? = nil, arm: String? = nil, position: String? = nil, tags: [String] = [], note: String = "") {
        self.readingID = readingID
        self.arm = arm
        self.position = position
        self.tags = tags
        self.note = note
    }

    init(metadata: [String: Any]?) {
        let m = metadata ?? [:]
        readingID = (m[HKMetadataKeyExternalUUID] as? String).flatMap(UUID.init(uuidString:))
        arm = m[Self.armKey] as? String
        position = m[Self.positionKey] as? String
        tags = (m[Self.tagsKey] as? String)?.split(separator: "\n").map(String.init) ?? []
        note = m[Self.noteKey] as? String ?? ""
    }

    /// Our keys plus `WasUserEntered`: these numbers were typed, not measured by a device.
    var metadata: [String: Any] {
        var m: [String: Any] = [HKMetadataKeyWasUserEntered: true]
        if let readingID { m[HKMetadataKeyExternalUUID] = readingID.uuidString }
        if let arm { m[Self.armKey] = arm }
        if let position { m[Self.positionKey] = position }
        if !tags.isEmpty { m[Self.tagsKey] = tags.joined(separator: "\n") }
        if !note.isEmpty { m[Self.noteKey] = note }
        return m
    }
}

extension HealthMeta {
    init(_ r: Reading) {
        self.init(readingID: r.id, arm: r.armRaw, position: r.positionRaw, tags: r.tags, note: r.note)
    }
}

/// Opt-in Apple Health bridge: writes manual readings as blood pressure
/// correlations (+ heart rate) and imports what other apps and smart cuffs
/// wrote. Apple Health also syncs across the user's devices, so importing our
/// own writes back is how a new phone gets its history. Health data never
/// leaves the device through us — no analytics, no ads (guideline 5.1.3).
enum HealthService {
    private static let store = HKHealthStore()
    private static let pressure = HKCorrelationType(.bloodPressure)
    private static let systolic = HKQuantityType(.bloodPressureSystolic)
    private static let diastolic = HKQuantityType(.bloodPressureDiastolic)
    private static let heartRate = HKQuantityType(.heartRate)
    private static let mmHg = HKUnit.millimeterOfMercury()
    private static let bpm = HKUnit.count().unitDivided(by: .minute())

    /// A cuff writes pulse as a separate sample a moment apart from the pressure.
    nonisolated static let pulseMatchWindow: TimeInterval = 120

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows the system sheet. `true` means the request went through, not that
    /// every type was granted — HealthKit never reveals read permission.
    /// Blood pressure is authorized through its two quantity types, never the correlation type.
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let types: Set = [systolic, diastolic, heartRate]
        do {
            try await store.requestAuthorization(toShare: types, read: types)
            return true
        } catch {
            return false
        }
    }

    /// Writes the reading and returns the correlation UUID to store in `Reading.healthKitID`.
    static func save(_ reading: ReadingValue, meta: HealthMeta) async -> UUID? {
        guard isAvailable, store.authorizationStatus(for: systolic) == .sharingAuthorized else { return nil }
        let date = reading.date
        let objects: Set<HKSample> = [
            HKQuantitySample(type: systolic, quantity: HKQuantity(unit: mmHg, doubleValue: Double(reading.systolic)), start: date, end: date),
            HKQuantitySample(type: diastolic, quantity: HKQuantity(unit: mmHg, doubleValue: Double(reading.diastolic)), start: date, end: date),
        ]
        let correlation = HKCorrelation(type: pressure, start: date, end: date, objects: objects, metadata: meta.metadata)
        do {
            try await store.save(correlation)
        } catch {
            return nil
        }
        if let pulse = reading.pulse {
            try? await store.save(HKQuantitySample(type: heartRate, quantity: HKQuantity(unit: bpm, doubleValue: Double(pulse)), start: date, end: date))
        }
        return correlation.uuid
    }

    /// Deletes our own write: the correlation and the heart rate sample saved with it.
    static func delete(healthKitID: UUID, date: Date) async {
        guard isAvailable else { return }
        let own = HKQuery.predicateForObjects(from: .default())
        let byID = HKQuery.predicateForObject(with: healthKitID)
        _ = try? await store.deleteObjects(of: pressure, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [own, byID]))
        let atDate = HKQuery.predicateForSamples(withStart: date, end: date, options: [.strictStartDate, .strictEndDate])
        _ = try? await store.deleteObjects(of: heartRate, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [own, atDate]))
    }

    /// Every blood pressure correlation since `since`, from any source, with the closest pulse attached.
    static func fetchReadings(since: Date) async -> [HealthReading] {
        guard isAvailable else { return [] }
        let range = HKQuery.predicateForSamples(withStart: since, end: nil)
        let pressureQuery = HKSampleQueryDescriptor(predicates: [.correlation(type: pressure, predicate: range)], sortDescriptors: [])
        let pulseQuery = HKSampleQueryDescriptor(predicates: [.quantitySample(type: heartRate, predicate: range)], sortDescriptors: [])
        guard let correlations = try? await pressureQuery.result(for: store) else { return [] }
        let pulses = ((try? await pulseQuery.result(for: store)) ?? [])
            .map { (date: $0.startDate, bpm: Int($0.quantity.doubleValue(for: bpm).rounded())) }

        return correlations.compactMap { c in
            guard let sys = (c.objects(for: systolic).first as? HKQuantitySample)?.quantity.doubleValue(for: mmHg),
                  let dia = (c.objects(for: diastolic).first as? HKQuantitySample)?.quantity.doubleValue(for: mmHg)
            else { return nil }
            return HealthReading(id: c.uuid, date: c.startDate, systolic: Int(sys.rounded()), diastolic: Int(dia.rounded()),
                                 pulse: closestPulse(to: c.startDate, in: pulses),
                                 sourceBundleID: c.sourceRevision.source.bundleIdentifier,
                                 meta: HealthMeta(metadata: c.metadata))
        }
    }

    /// Imports readings we don't have yet — from cuffs and other apps, and our
    /// own writes synced from another device or left from a previous install.
    /// Returns how many were added.
    @discardableResult
    static func importNew(into context: ModelContext) async -> Int {
        let since = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? .distantPast
        let health = await fetchReadings(since: since)
        let local = (try? context.fetch(FetchDescriptor<Reading>())) ?? []
        let fresh = newImports(health, existingHealthIDs: Set(local.compactMap(\.healthKitID)), existingReadingIDs: Set(local.map(\.id)))
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        for h in fresh {
            context.insert(makeReading(h, ownBundleID: ownBundleID))
        }
        if !fresh.isEmpty { try? context.save() }
        return fresh.count
    }

    /// Writes readings typed here that never reached Health (entered before
    /// Health was turned on). Returns how many were saved.
    @discardableResult
    static func backfill(_ context: ModelContext) async -> Int {
        let pending = ((try? context.fetch(FetchDescriptor<Reading>())) ?? [])
            .filter { $0.source == .manual && $0.healthKitID == nil }
        var saved = 0
        for r in pending {
            if let id = await save(r.value, meta: HealthMeta(r)) {
                r.healthKitID = id
                saved += 1
            }
        }
        if saved > 0 { try? context.save() }
        return saved
    }

    /// Skips what we already hold, matched both on the Health sample and on our
    /// own reading id — a reading restored from a JSON backup and its Health copy are one reading.
    nonisolated static func newImports(_ health: [HealthReading], existingHealthIDs: Set<UUID>, existingReadingIDs: Set<UUID>) -> [HealthReading] {
        health.filter { h in
            !existingHealthIDs.contains(h.id) && !(h.meta.readingID.map(existingReadingIDs.contains) ?? false)
        }
    }

    /// Our own writes come back as manual readings with their original id;
    /// anything else is a Health import whose numbers belong to its source app.
    static func makeReading(_ h: HealthReading, ownBundleID: String) -> Reading {
        let own = h.sourceBundleID == ownBundleID
        let r = Reading(date: h.date, systolic: h.systolic, diastolic: h.diastolic, pulse: h.pulse,
                        tags: h.meta.tags, note: h.meta.note, source: own ? .manual : .health, healthKitID: h.id)
        if own, let id = h.meta.readingID { r.id = id }
        if let arm = h.meta.arm { r.armRaw = arm }
        if let position = h.meta.position { r.positionRaw = position }
        return r
    }

    /// The pulse sample closest in time, if one lies within `pulseMatchWindow`.
    nonisolated static func closestPulse(to date: Date, in pulses: [(date: Date, bpm: Int)]) -> Int? {
        pulses
            .filter { abs($0.date.timeIntervalSince(date)) <= pulseMatchWindow }
            .min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?
            .bpm
    }
}
