import Foundation
import SwiftData
import Testing
@testable import TachoBook

/// Printout state and time are saved with the violation (owner decisions 9 and 16) and survive relaunch; a store
/// written before this change (schema V1) opens without losing shifts.
@MainActor
struct ViolationPersistenceTests {
    private let start = Date(timeIntervalSince1970: 1_791_957_600) // 2026-10-14 06:00 UTC

    private func withDisk(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "swiftdata-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appending(path: "shifts.store"))
    }

    private func withModel<T>(_ url: URL, _ body: (DayLogModel) throws -> T) rethrows -> T {
        try autoreleasepool { try body(DayLogModel(storageURL: url)) }
    }

    @Test func printoutSurvivesRelaunchAndMarkAsNotDoneClearsIt() throws {
        try withDisk { url in
            let now = start.addingTimeInterval(17 * 3600)
            let key = try withModel(url) { model in
                // No weekly rest in the records: only past 15 h is certain.
                model.setDayStart(start)
                model.closeShift(at: start.addingTimeInterval(16 * 3600), now: now)
                let violation = try #require(model.violations(now: now).first { $0.kind == .dutyLimit })
                model.markPrintout(now, for: violation, now: now)
                try #require(model.storageError == nil)
                return violation.key
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.printout(for: key) == now)
                let violation = try #require(model.violation(for: key, now: now))
                #expect(model.carryStatus(of: violation, now: now).daysLeft == 56)
                model.clearPrintout(for: key)
            }
            try withModel(url) { model in
                #expect(model.printout(for: key) == nil)
                #expect(model.violation(for: key, now: now) != nil, "the violation itself stays")
            }
        }
    }

    @Test func storeWrittenBeforePrintoutsOpensWithItsShifts() throws {
        try withDisk { url in
            let period = DutyPeriod(date: start, start: start, drivingMinutes: 90)
            try autoreleasepool {
                let schema = Schema(versionedSchema: ShiftSchemaV1.self)
                let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)
                context.insert(ShiftSchemaV1.Period(period: period, isCurrent: true, archiveOrder: 0,
                                                   restData: try JSONEncoder().encode([RestSegment]())))
                try context.save()
            }
            let now = start.addingTimeInterval(16 * 3600)
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dutyID == period.id)
                #expect(model.dayStart == start)
                #expect(model.drivingMinutes == 90)
                let violation = try #require(model.currentDutyViolation(now: now))
                model.markPrintout(now, for: violation, now: now)
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.printout(for: ViolationKey(periodID: period.id, kind: .dutyLimit)) == now)
            }
        }
    }

    @Test func keyRoundTripsThroughItsStoredForm() {
        let key = ViolationKey(periodID: UUID(), kind: .shortRest)
        #expect(ViolationKey(storageID: key.storageID) == key)
        #expect(ViolationKey(storageID: "not a key") == nil)
    }
}
