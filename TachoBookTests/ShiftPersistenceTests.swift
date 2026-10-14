import Foundation
import SwiftData
import Testing
@testable import TachoBook

@MainActor
struct ShiftPersistenceTests {
    private let start = Date(timeIntervalSince1970: 1_791_957_600) // 2026-10-14 06:00 UTC

    private func withDisk(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "swiftdata-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appending(path: "shifts.store"))
    }

    // Each invocation owns and releases its model/context/container. Only value
    // types cross the boundary; a second invocation opens the same real disk file.
    private func withModel<T>(_ url: URL, legacyURL: URL? = nil, _ body: (DayLogModel) throws -> T) rethrows -> T {
        try autoreleasepool { try body(DayLogModel(storageURL: url, legacyURL: legacyURL)) }
    }

    @Test func sixAMStartReloadsAtTenAMWithoutDuplicateOrCalendarReset() throws {
        try withDisk { url in
            let id = try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dayStart == nil)
                #expect(model.archivedPeriods.isEmpty)
                model.setDayStart(start)
                model.setDrivingMinutes(240)
                try #require(model.storageError == nil)
                return model.dutyID
            }
            for _ in 0..<3 {
                try withModel(url) { model in
                    try #require(model.storageError == nil)
                    #expect(model.dutyID == id)
                    #expect(model.dayStart == start)
                    #expect(model.drivingMinutes == 240)
                    #expect(model.isShiftOpen)
                    #expect(model.shiftDurationString(at: start.addingTimeInterval(4 * 3600)) == "4:00")
                    #expect(model.shiftElapsedSeconds(at: start.addingTimeInterval(26 * 3600)) == 93600)
                    #expect(model.archivedPeriods.isEmpty)
                }
            }
            let store = try ShiftStore(url: url)
            #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<ShiftSchemaV1.Period>()) == 1)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func closeResumeEditsAndDeletionSurviveReleasedContainers() throws {
        try withDisk { url in
            let id = withModel(url) { model in
                model.setDayStart(start)
                model.setDrivingMinutes(120)
                model.closeShift(at: start.addingTimeInterval(4 * 3600))
                return model.dutyID
            }
            let restID = try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.isDayClosed)
                #expect(model.dayEnd == start.addingTimeInterval(4 * 3600))
                #expect(model.shiftElapsedSeconds(at: start.addingTimeInterval(7 * 3600)) == 14400)
                let rest = try #require(model.restSegments.first)
                model.resumeShift(at: start.addingTimeInterval(5 * 3600))
                model.setDrivingMinutes(200)
                return rest.id
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dutyID == id)
                #expect(model.dayStart == start)
                #expect(model.dayEnd == nil)
                #expect(model.isDayClosed == false)
                #expect(model.drivingMinutes == 200)
                #expect(model.restSegments.first?.id == restID)
                #expect(model.restSegments.first?.end == start.addingTimeInterval(5 * 3600))
                model.deleteEntry(.driving)
                model.closeShift(at: start.addingTimeInterval(6 * 3600))
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.drivingMinutes == nil)
                #expect(model.isDayClosed)
                #expect(model.restSegments.count == 2)
                #expect(model.restSegments.first?.id == restID)
            }
        }
    }

    @Test func archivesAndResetRetainPreviousPeriodsAndPersistEmptyCurrent() throws {
        try withDisk { url in
            let ids = withModel(url) { model in
                var ids: [UUID] = []
                for day in 0..<3 {
                    let date = start.addingTimeInterval(Double(day) * 86400)
                    model.setDayStart(date)
                    model.setDrivingMinutes(100 + day)
                    ids.append(model.dutyID)
                    model.closeShift(at: date.addingTimeInterval(3600))
                    model.startNewShift(at: date.addingTimeInterval(12 * 3600), dailyRestConfirmed: true)
                }
                return ids
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.archivedPeriods.map(\.id) == ids)
                #expect(model.archivedPeriods.map(\.drivingMinutes) == [100, 101, 102])
                #expect(model.archivedPeriods.allSatisfy { $0.rests.first?.dailyRestConfirmed == true })
                model.resetToInitial()
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dayStart == nil)
                #expect(model.dayEnd == nil)
                #expect(model.drivingMinutes == nil)
                #expect(model.isDayClosed == false)
                #expect(model.archivedPeriods.map(\.id) == ids)
            }
            let store = try ShiftStore(url: url)
            #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<ShiftSchemaV1.Period>()) == 4)
        }
    }

    @Test func deletingEditableStartAndEndSurvivesReload() throws {
        try withDisk { url in
            withModel(url) { model in
                model.setDayStart(start)
                model.setDayEnd(start.addingTimeInterval(3600))
                model.deleteEntry(.dayEnd)
            }
            withModel(url) { model in
                #expect(model.dayStart == start)
                #expect(model.dayEnd == nil)
                model.deleteEntry(.dayStart)
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dayStart == nil)
                #expect(model.isDayClosed == false)
            }
        }
    }

    @Test(arguments: ["2026-03-28T22:00:00+01:00", "2026-10-24T22:00:00+02:00"])
    func absoluteTimestampsAndOriginalTimezoneSurviveDST(iso: String) throws {
        let instant = try #require(ISO8601DateFormatter().date(from: iso))
        try withDisk { url in
            let zone = withModel(url) { model in
                model.setDayStart(instant)
                model.closeShift(at: instant.addingTimeInterval(9 * 3600))
                return TimeZone.current.identifier
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dayStart == instant)
                #expect(model.dayEnd == instant.addingTimeInterval(9 * 3600))
                #expect(model.shiftElapsedSeconds(at: instant.addingTimeInterval(20 * 3600)) == 32400)
                #expect(model.restSegments.first?.start == instant.addingTimeInterval(9 * 3600))
            }
            let store = try ShiftStore(url: url)
            let saved = try #require(try store.load(legacyURL: nil))
            #expect(saved.current.calendarZone == zone)
        }
    }

    @Test func legacyJournalImportsOnceWithoutDeletingOrReimportingAfterReset() throws {
        try withDisk { url in
            let legacy = url.deletingLastPathComponent().appending(path: "shift-journal-v1.json")
            let previous = DutyPeriod(date: start.addingTimeInterval(-86400), start: start.addingTimeInterval(-86400))
            let current = DutyPeriod(date: start, start: start, drivingMinutes: 88, end: start.addingTimeInterval(3600),
                                     isClosed: true, rests: [RestSegment(start: start.addingTimeInterval(3600))])
            let bytes = try JSONEncoder().encode(ShiftJournal(current: current, history: [previous]))
            try bytes.write(to: legacy)
            try withModel(url, legacyURL: legacy) { model in
                try #require(model.storageError == nil)
                #expect(model.dutyID == current.id)
                #expect(model.restSegments == current.rests)
                #expect(model.archivedPeriods.first?.id == previous.id)
                model.resetToInitial()
            }
            try withModel(url, legacyURL: legacy) { model in
                try #require(model.storageError == nil)
                #expect(model.dayStart == nil)
                #expect(model.dutyID != current.id)
                #expect(model.archivedPeriods.count == 1)
                #expect(try Data(contentsOf: legacy) == bytes)
            }
        }
    }

    @Test func unreadableLegacyAndFailedDiskStoreStayLockedAndPreserved() throws {
        try withDisk { url in
            let legacy = url.deletingLastPathComponent().appending(path: "broken.json")
            let bytes = Data("unreadable".utf8)
            try bytes.write(to: legacy)
            withModel(url, legacyURL: legacy) { model in
                #expect(model.storageError != nil)
                model.setDayStart(start)
                #expect(model.dayStart == nil)
            }
            #expect(try Data(contentsOf: legacy) == bytes)
            let blocked = url.deletingLastPathComponent().appending(path: "not-a-directory")
            try bytes.write(to: blocked)
            withModel(blocked.appending(path: "store")) { model in
                #expect(model.storageError != nil)
                model.setDrivingMinutes(60)
                #expect(model.drivingMinutes == nil)
            }
            #expect(try Data(contentsOf: blocked) == bytes)
        }
    }
}
