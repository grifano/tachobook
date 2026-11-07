import Foundation
import SwiftData

enum ShiftSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Period.self] }

    @Model
    final class Period {
        @Attribute(.unique) var id: UUID
        var calendarZone: String
        var date: Date
        var start: Date?
        var drivingMinutes: Int?
        var end: Date?
        var isClosed: Bool
        var isCurrent: Bool
        var archiveOrder: Int
        // The ordered value segments are not queried independently. Encoding them
        // explicitly avoids relying on SwiftData's implicit Codable transformers.
        var restData: Data

        init(period: DutyPeriod, isCurrent: Bool, archiveOrder: Int, restData: Data) {
            id = period.id
            calendarZone = period.calendarZone
            date = period.date
            start = period.start
            drivingMinutes = period.drivingMinutes
            end = period.end
            isClosed = period.isClosed
            self.isCurrent = isCurrent
            self.archiveOrder = archiveOrder
            self.restData = restData
        }

        func value() throws -> DutyPeriod {
            DutyPeriod(id: id, calendarZone: calendarZone, date: date, start: start,
                       drivingMinutes: drivingMinutes, end: end, isClosed: isClosed,
                       rests: try JSONDecoder().decode([RestSegment].self, from: restData))
        }
    }
}

/// V2 adds the printout of each violation (owner decisions 9 and 16). Shift records are unchanged.
enum ShiftSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [ShiftSchemaV1.Period.self, Printout.self] }

    @Model
    final class Printout {
        /// `ViolationKey.storageID`: the shift record and the violation kind.
        @Attribute(.unique) var violation: String
        var printedAt: Date

        init(violation: String, printedAt: Date) {
            self.violation = violation
            self.printedAt = printedAt
        }
    }
}

enum ShiftMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ShiftSchemaV1.self, ShiftSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: ShiftSchemaV1.self, toVersion: ShiftSchemaV2.self)] }
}

enum ShiftStoreError: LocalizedError {
    case invalidJournal

    var errorDescription: String? {
        "Saved shift records are inconsistent. The store has been preserved; no new shift was created."
    }
}

@MainActor
final class ShiftStore {
    let container: ModelContainer
    private let context: ModelContext

    init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: ShiftSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, migrationPlan: ShiftMigrationPlan.self, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func load(legacyURL: URL?) throws -> ShiftJournal? {
        let records = try context.fetch(FetchDescriptor<ShiftSchemaV1.Period>(sortBy: [SortDescriptor(\.archiveOrder)]))
        if records.isEmpty {
            guard let legacyURL, FileManager.default.fileExists(atPath: legacyURL.path) else { return nil }
            let journal = try JSONDecoder().decode(ShiftJournal.self, from: Data(contentsOf: legacyURL))
            try save(journal)
            // Keep the original JSON as a recovery copy. A saved empty current
            // record also prevents importing it again after reset/deletion.
            return journal
        }
        let current = records.filter(\.isCurrent)
        guard current.count == 1 else { throw ShiftStoreError.invalidJournal }
        var printouts: [ViolationKey: Date] = [:]
        for printout in try context.fetch(FetchDescriptor<ShiftSchemaV2.Printout>()) {
            if let key = ViolationKey(storageID: printout.violation) { printouts[key] = printout.printedAt }
        }
        return try ShiftJournal(current: current[0].value(), history: records.filter { !$0.isCurrent }.map { try $0.value() },
                                printouts: printouts)
    }

    func save(_ journal: ShiftJournal) throws {
        let periods = journal.history + [journal.current]
        guard Set(periods.map(\.id)).count == periods.count else { throw ShiftStoreError.invalidJournal }
        // Encode before touching the context so a failed encoding cannot leave
        // a partially changed journal. Save all command changes in one transaction.
        let encoded = try periods.map { try JSONEncoder().encode($0.rests) }
        do {
            let records = try context.fetch(FetchDescriptor<ShiftSchemaV1.Period>())
            let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
            for (index, period) in periods.enumerated() {
                let record = byID[period.id] ?? ShiftSchemaV1.Period(
                    period: period, isCurrent: period.id == journal.current.id,
                    archiveOrder: index, restData: encoded[index])
                if byID[period.id] == nil { context.insert(record) }
                record.calendarZone = period.calendarZone
                record.date = period.date
                record.start = period.start
                record.drivingMinutes = period.drivingMinutes
                record.end = period.end
                record.isClosed = period.isClosed
                record.isCurrent = period.id == journal.current.id
                record.archiveOrder = index
                record.restData = encoded[index]
            }
            let ids = Set(periods.map(\.id))
            for record in records where !ids.contains(record.id) { context.delete(record) }
            // A printout outlives an edit that hides its violation, so it is back if the violation returns (R-E01).
            let printouts = Dictionary(uniqueKeysWithValues: journal.printouts.map { ($0.key.storageID, $0.value) })
            let saved = try context.fetch(FetchDescriptor<ShiftSchemaV2.Printout>())
            for printout in saved {
                if let date = printouts[printout.violation] {
                    printout.printedAt = date
                } else {
                    context.delete(printout)
                }
            }
            let savedIDs = Set(saved.map(\.violation))
            for (violation, date) in printouts where !savedIDs.contains(violation) {
                context.insert(ShiftSchemaV2.Printout(violation: violation, printedAt: date))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
