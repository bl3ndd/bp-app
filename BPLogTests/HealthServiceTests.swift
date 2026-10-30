import Testing
import Foundation
@testable import BPLog

struct HealthServiceTests {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    static let own = "white.tea.BPLog"

    static func h(_ id: UUID = UUID(), source: String = "com.omron.app", meta: HealthMeta = HealthMeta()) -> HealthReading {
        HealthReading(id: id, date: t0, systolic: 128, diastolic: 82, pulse: 70, sourceBundleID: source, meta: meta)
    }

    @Test func importSkipsKnownSamples() {
        let known = UUID()
        let cuff = Self.h()
        let fresh = HealthService.newImports([Self.h(known), cuff], existingHealthIDs: [known], existingReadingIDs: [])
        #expect(fresh == [cuff])
    }

    @Test func ownWritesComeBackOnAFreshInstall() {
        let mine = Self.h(source: Self.own, meta: HealthMeta(readingID: UUID()))
        #expect(HealthService.newImports([mine], existingHealthIDs: [], existingReadingIDs: []) == [mine])
    }

    @Test func readingRestoredFromBackupIsNotImportedTwice() {
        let readingID = UUID()
        let mine = Self.h(source: Self.own, meta: HealthMeta(readingID: readingID))
        #expect(HealthService.newImports([mine], existingHealthIDs: [], existingReadingIDs: [readingID]).isEmpty)
    }

    @Test func importIsIdempotent() {
        let readings = [Self.h(), Self.h()]
        let first = HealthService.newImports(readings, existingHealthIDs: [], existingReadingIDs: [])
        let second = HealthService.newImports(readings, existingHealthIDs: Set(first.map(\.id)), existingReadingIDs: [])
        #expect(first.count == 2)
        #expect(second.isEmpty)
    }

    @Test func metadataRoundTrip() {
        let meta = HealthMeta(readingID: UUID(), arm: "right", position: "standing", tags: ["Stressed", "After coffee"], note: "after work")
        #expect(HealthMeta(metadata: meta.metadata) == meta)
        #expect(HealthMeta(metadata: nil) == HealthMeta())
        #expect(HealthMeta(metadata: HealthMeta().metadata) == HealthMeta())
    }

    @MainActor @Test func ownWriteRestoresAsManualWithItsId() {
        let readingID = UUID()
        let mine = Self.h(source: Self.own, meta: HealthMeta(readingID: readingID, arm: "right", position: "lying", tags: ["Headache"], note: "n"))
        let r = HealthService.makeReading(mine, ownBundleID: Self.own)
        #expect(r.id == readingID)
        #expect(r.source == .manual)
        #expect(r.healthKitID == mine.id)
        #expect(r.arm == .right && r.position == .lying)
        #expect(r.tags == ["Headache"] && r.note == "n")
    }

    @MainActor @Test func cuffReadingImportsAsHealth() {
        let cuff = Self.h()
        let r = HealthService.makeReading(cuff, ownBundleID: Self.own)
        #expect(r.source == .health)
        #expect(r.healthKitID == cuff.id)
        #expect(r.value == ReadingValue(date: Self.t0, systolic: 128, diastolic: 82, pulse: 70))
    }

    @Test func pulseMatchesClosestWithinWindow() {
        let pulses = [(date: Self.t0.addingTimeInterval(-90), bpm: 64),
                      (date: Self.t0.addingTimeInterval(30), bpm: 72),
                      (date: Self.t0.addingTimeInterval(500), bpm: 99)]
        #expect(HealthService.closestPulse(to: Self.t0, in: pulses) == 72)
        #expect(HealthService.closestPulse(to: Self.t0.addingTimeInterval(-200), in: pulses) == 64)
        #expect(HealthService.closestPulse(to: Self.t0.addingTimeInterval(-1000), in: pulses) == nil)
        #expect(HealthService.closestPulse(to: Self.t0, in: []) == nil)
    }
}

extension HealthServiceTests {
    @Test func deletedReadingsNeverComeBack() {
        let cuff = Self.h()
        let mineID = UUID()
        let mine = Self.h(source: Self.own, meta: HealthMeta(readingID: mineID))
        let fresh = HealthService.newImports([cuff, mine], existingHealthIDs: [], existingReadingIDs: [],
                                             deletedIDs: [cuff.id, mineID])
        #expect(fresh.isEmpty)
    }

    @MainActor @Test func deletionsArePersisted() {
        let defaults = UserDefaults(suiteName: "HealthServiceTests-\(UUID())")!
        let id = UUID()
        AppSettings(defaults: defaults).rememberDeleted([id])
        #expect(AppSettings(defaults: defaults).deletedIDs == [id])
    }
}
