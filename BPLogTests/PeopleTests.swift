import Testing
import Foundation
import SwiftData
@testable import BPLog

@MainActor
struct PeopleTests {
    private func makeSettings() -> (AppSettings, UserDefaults) {
        let defaults = UserDefaults(suiteName: "PeopleTests-\(UUID())")!
        return (AppSettings(defaults: defaults), defaults)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Reading.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test func ownerIsMeUntilRenamed() {
        let (settings, _) = makeSettings()
        #expect(settings.people.isEmpty)
        #expect(settings.activePersonID == nil)
        #expect(settings.activeName == "Me")
        settings.ownerName = "Alex"
        #expect(settings.name(of: nil) == "Alex")
    }

    @Test func peopleAndActivePersonSurviveRelaunch() {
        let (settings, defaults) = makeSettings()
        let sam = settings.addPerson(named: "  Sam ")
        settings.activePersonID = sam.id
        settings.rename(sam.id, to: "Sammy")

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.people == [Person(id: sam.id, name: "Sammy")])
        #expect(reloaded.activePersonID == sam.id)
        #expect(reloaded.activeName == "Sammy")
    }

    @Test func removingTheActivePersonFallsBackToTheOwner() {
        let (settings, defaults) = makeSettings()
        let sam = settings.addPerson(named: "Sam")
        settings.activePersonID = sam.id
        settings.removePerson(sam.id)
        #expect(settings.people.isEmpty)
        #expect(settings.activePersonID == nil)
        #expect(AppSettings(defaults: defaults).activePersonID == nil)
    }

    @Test func activePersonMissingFromTheListIsIgnoredOnLaunch() {
        let (_, defaults) = makeSettings()
        defaults.set(UUID().uuidString, forKey: "activePersonID")
        #expect(AppSettings(defaults: defaults).activePersonID == nil)
    }

    @Test func mergeAddsOnlyNewPeople() {
        let (settings, _) = makeSettings()
        let sam = settings.addPerson(named: "Sam")
        let kim = Person(name: "Kim")
        settings.merge([Person(id: sam.id, name: "Old name"), kim])
        #expect(settings.people == [sam, kim])
    }

    @Test func readingsFilterByPerson() {
        let sam = UUID()
        let mine = Reading(systolic: 120, diastolic: 80)
        let his = Reading(systolic: 140, diastolic: 90, personID: sam)
        #expect([mine, his].of(nil).map(\.id) == [mine.id])
        #expect([mine, his].of(sam).map(\.id) == [his.id])
    }

    @Test func backupKeepsPeopleAndWhoseReadingItIs() throws {
        let sam = Person(name: "Sam")
        let readings = [Reading(systolic: 120, diastolic: 80), Reading(systolic: 140, diastolic: 90, personID: sam.id)]
        let data = try BackupService.export(readings, people: [sam])
        let context = try makeContext()
        let result = try BackupService.restore(from: data, into: context)
        #expect(result == BackupService.ImportResult(added: 2, skipped: 0, people: [sam]))
        let restored = try context.fetch(FetchDescriptor<Reading>())
        #expect(Set(restored.map(\.personID)) == [nil, sam.id])
    }

    @Test func backupFromVersionOneRestoresAsTheOwner() throws {
        let json = """
        {"version":1,"exportedAt":"2026-10-30T10:00:00Z","readings":[{"id":"\(UUID().uuidString)",
        "date":"2026-10-30T08:00:00Z","systolic":128,"diastolic":82,"arm":"left","position":"sitting",
        "tags":[],"note":"","source":"manual"}]}
        """
        let context = try makeContext()
        let result = try BackupService.restore(from: Data(json.utf8), into: context)
        #expect(result == BackupService.ImportResult(added: 1, skipped: 0))
        #expect(try context.fetch(FetchDescriptor<Reading>()).first?.personID == nil)
    }
}
