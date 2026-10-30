import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Plain-JSON export and import of every reading. Free for everyone: health
/// data can't live in our iCloud (guideline 5.1.3), so a file the user keeps
/// themselves is how they move to a new phone or undo a mistake.
///
/// The archive has its own structs rather than the @Model class, so the file
/// format stays readable by future versions whatever SwiftData stores.
enum BackupService {
    static let formatVersion = 1

    nonisolated struct Archive: Codable, Equatable {
        var version: Int
        var exportedAt: Date
        var readings: [Item]
    }

    nonisolated struct Item: Codable, Equatable {
        var id: UUID
        var date: Date
        var systolic: Int
        var diastolic: Int
        var pulse: Int?
        var arm: String
        var position: String
        var tags: [String]
        var note: String
        var source: String
        var healthKitID: UUID?
    }

    /// What an import actually did, so the UI reports it honestly.
    struct ImportResult: Equatable {
        var added: Int
        var skipped: Int
    }

    static func export(_ readings: [Reading], now: Date = Date()) throws -> Data {
        let archive = Archive(version: formatVersion, exportedAt: now, readings: readings.map(Item.init(from:)))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    /// Additive: a reading already on the device (same id) is left alone, so
    /// restoring can never destroy what's there.
    @discardableResult
    static func restore(from data: Data, into context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(Archive.self, from: data)
        let existing = Set(((try? context.fetch(FetchDescriptor<Reading>())) ?? []).map(\.id))
        var result = ImportResult(added: 0, skipped: 0)
        for item in archive.readings {
            guard !existing.contains(item.id) else { result.skipped += 1; continue }
            context.insert(item.makeModel())
            result.added += 1
        }
        try context.save()
        return result
    }

    static func filename(now: Date = Date()) -> String {
        "bp-log-backup-\(now.formatted(.iso8601.year().month().day()))"
    }
}

private extension BackupService.Item {
    init(from r: Reading) {
        id = r.id
        date = r.date
        systolic = r.systolic
        diastolic = r.diastolic
        pulse = r.pulse
        arm = r.armRaw
        position = r.positionRaw
        tags = r.tags
        note = r.note
        source = r.sourceRaw
        healthKitID = r.healthKitID
    }

    func makeModel() -> Reading {
        let r = Reading(date: date, systolic: systolic, diastolic: diastolic, pulse: pulse,
                        tags: tags, note: note, healthKitID: healthKitID)
        r.id = id
        r.armRaw = arm
        r.positionRaw = position
        r.sourceRaw = source
        return r
    }
}

/// Thin wrapper so `fileExporter` can write the archive straight to Files.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
