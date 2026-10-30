import Testing
import Foundation
import SwiftData
@testable import BPLog

@MainActor
struct BackupServiceTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Reading.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func sample() -> Reading {
        let r = Reading(date: Date(timeIntervalSince1970: 1_800_000_000), systolic: 128, diastolic: 82, pulse: 70,
                        arm: .right, position: .standing, tags: ["Stressed"], note: "after work",
                        source: .health, healthKitID: UUID())
        return r
    }

    @Test func roundTripKeepsEveryField() throws {
        let original = sample()
        let data = try BackupService.export([original])
        let context = try makeContext()
        let result = try BackupService.restore(from: data, into: context)
        #expect(result == BackupService.ImportResult(added: 1, skipped: 0))
        let restored = try #require(try context.fetch(FetchDescriptor<Reading>()).first)
        #expect(restored.id == original.id)
        #expect(restored.date == original.date)
        #expect(restored.value == original.value)
        #expect(restored.arm == .right)
        #expect(restored.position == .standing)
        #expect(restored.tags == ["Stressed"])
        #expect(restored.note == "after work")
        #expect(restored.source == .health)
        #expect(restored.healthKitID == original.healthKitID)
    }

    @Test func restoreIsAdditive() throws {
        let existing = sample()
        let context = try makeContext()
        context.insert(existing)
        let data = try BackupService.export([existing, Reading(systolic: 140, diastolic: 90)])
        let result = try BackupService.restore(from: data, into: context)
        #expect(result == BackupService.ImportResult(added: 1, skipped: 1))
        #expect(try context.fetch(FetchDescriptor<Reading>()).count == 2)
    }

    @Test func rejectsForeignFile() throws {
        let context = try makeContext()
        #expect(throws: (any Error).self) {
            try BackupService.restore(from: Data(#"{"hello":"world"}"#.utf8), into: context)
        }
    }

    @Test func filenameHasDate() {
        let name = BackupService.filename(now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(name.hasPrefix("bp-log-backup-2027-01-"))
    }
}
