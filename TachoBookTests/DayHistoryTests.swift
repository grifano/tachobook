import Foundation
import SwiftData
import Testing
@testable import TachoBook

/// MVP-07 History and correction: day assignment, validation (R-E01) and rest taken, in Europe/Berlin.
/// "Now" is Monday 19 October 2026 12:00; days back 1…3 are 18, 17 and 16 October.
@MainActor
struct DayHistoryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private var now: Date { date(19, 12) }
    private func day(_ number: Int) -> Date { calendar.startOfDay(for: date(number, 0)) }

    private func enter(_ model: DayLogModel, day number: Int, start: Date? = nil, end: Date? = nil, driving: Int? = nil) {
        if let start { model.setStart(start, onDay: day(number), now: now, calendar: calendar) }
        if let end { model.setEnd(end, onDay: day(number), now: now, calendar: calendar) }
        if let driving { model.setDriving(minutes: driving, onDay: day(number), calendar: calendar) }
    }

    // MARK: - Depth and day assignment

    @Test func historyReachesThreeDaysBack() {
        #expect(DayHistory.maxDaysBack == 3)
        #expect(DayHistory.day(daysBack: 0, from: now, calendar: calendar) == day(19))
        #expect(DayHistory.day(daysBack: 3, from: now, calendar: calendar) == day(16))
    }

    @Test func shiftAcrossMidnightStaysOnItsStartDate() throws {
        let model = DayLogModel()
        enter(model, day: 17, start: date(17, 22), end: date(18, 6), driving: 480)
        let record = model.dayRecord(on: day(17), calendar: calendar)
        #expect(record?.start == date(17, 22))
        #expect(record?.end == date(18, 6))
        #expect(model.dayRecord(on: day(18), calendar: calendar) == nil, "the end date does not own the shift")
        #expect(DayHistory.recordDay(try #require(record), calendar: calendar) == day(17))
    }

    @Test func startMustBeOnTheSelectedDay() {
        let model = DayLogModel()
        #expect(model.canSetStart(date(17, 8), onDay: day(17), now: now, calendar: calendar))
        #expect(!model.canSetStart(date(18, 0, 0), onDay: day(17), now: now, calendar: calendar))
        #expect(!model.canSetStart(date(16, 23, 59), onDay: day(17), now: now, calendar: calendar))
    }

    // MARK: - Empty day and browsing

    @Test func emptyDayHasNoRecordAndBrowsingChangesNothing() {
        let model = DayLogModel()
        for back in 0...3 {
            let target = DayHistory.day(daysBack: back, from: now, calendar: calendar)
            #expect(model.dayRecord(on: target, calendar: calendar) == nil)
            #expect(model.restTaken(after: model.dayRecord(on: target, calendar: calendar), now: now) == nil)
        }
        #expect(model.archivedPeriods.isEmpty)
        #expect(model.dayStart == nil)
    }

    @Test func browsingCreatesNoRecordInTheStore() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "day-history-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "shifts.store")
        try autoreleasepool {
            let model = DayLogModel(storageURL: url)
            for back in 0...3 {
                _ = model.dayRecord(on: DayHistory.day(daysBack: back, from: now, calendar: calendar), calendar: calendar)
            }
            #expect(model.storageError == nil)
        }
        let store = try ShiftStore(url: url)
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<ShiftSchemaV1.Period>()) == 0)
    }

    // MARK: - Entering and editing

    @Test func enteringThreeValuesOnAnEmptyDaySavesOneRecord() throws {
        let model = DayLogModel()
        enter(model, day: 17, start: date(17, 6), end: date(17, 14, 30), driving: 395)
        let record = try #require(model.dayRecord(on: day(17), calendar: calendar))
        #expect(record.start == date(17, 6))
        #expect(record.end == date(17, 14, 30))
        #expect(record.drivingMinutes == 395)
        #expect(model.archivedPeriods.count == 1)
        enter(model, day: 17, driving: 400)
        #expect(model.archivedPeriods.count == 1, "editing updates the record, it does not add one")
        #expect(model.dayRecord(on: day(17), calendar: calendar)?.drivingMinutes == 400)
    }

    @Test func aRecordMayHoldOnlySomeFields() throws {
        let model = DayLogModel()
        enter(model, day: 17, driving: 120)
        var record = try #require(model.dayRecord(on: day(17), calendar: calendar))
        #expect(record.drivingMinutes == 120 && record.start == nil && record.end == nil)
        enter(model, day: 17, end: date(17, 15))
        enter(model, day: 17, start: date(17, 7))
        record = try #require(model.dayRecord(on: day(17), calendar: calendar))
        #expect(record.start == date(17, 7) && record.end == date(17, 15) && record.drivingMinutes == 120)
        #expect(model.archivedPeriods.count == 1)
    }

    @Test func editingAStartRecomputesTheRestOfTheNeighbours() throws {
        let model = DayLogModel()
        enter(model, day: 16, start: date(16, 6), end: date(16, 14))
        enter(model, day: 17, start: date(17, 6), end: date(17, 14))
        let first = model.dayRecord(on: day(16), calendar: calendar)
        #expect(model.restTaken(after: first, now: now)?.seconds == 16 * 3600)
        enter(model, day: 17, start: date(17, 8))
        #expect(model.restTaken(after: first, now: now)?.seconds == 18 * 3600)
    }

    // MARK: - Validation (R-E01)

    @Test func endBeforeStartCannotBeConfirmed() {
        let model = DayLogModel()
        enter(model, day: 17, start: date(17, 10))
        #expect(!model.canSetEnd(date(17, 9, 59), onDay: day(17), now: now, calendar: calendar))
        #expect(model.canSetEnd(date(17, 10), onDay: day(17), now: now, calendar: calendar))
        enter(model, day: 17, end: date(17, 18))
        #expect(!model.canSetStart(date(17, 18, 1), onDay: day(17), now: now, calendar: calendar))
        model.setStart(date(17, 18, 1), onDay: day(17), now: now, calendar: calendar)
        #expect(model.dayRecord(on: day(17), calendar: calendar)?.start == date(17, 10), "rejected value is not stored")
    }

    @Test func endWithoutStartMustNotPrecedeTheDay() {
        let model = DayLogModel()
        #expect(!model.canSetEnd(date(16, 23), onDay: day(17), now: now, calendar: calendar))
        #expect(model.canSetEnd(date(18, 3), onDay: day(17), now: now, calendar: calendar), "night shift may end next day")
    }

    @Test func futureAndNegativeValuesAreRejected() {
        let model = DayLogModel()
        #expect(!model.canSetEnd(now.addingTimeInterval(60), onDay: day(19), now: now, calendar: calendar))
        #expect(!model.canSetDriving(minutes: -1))
        model.setDriving(minutes: -5, onDay: day(17), calendar: calendar)
        #expect(model.archivedPeriods.isEmpty)
    }

    @Test func overlapWithAnotherRecordIsRejectedButTouchingIsAllowed() {
        let model = DayLogModel()
        enter(model, day: 17, start: date(17, 22), end: date(18, 6))
        // Another day's shift that starts inside the night shift.
        #expect(!model.canSetStart(date(18, 5), onDay: day(18), now: now, calendar: calendar))
        // Starting at the instant the first one ended is not an overlap.
        #expect(model.canSetStart(date(18, 6), onDay: day(18), now: now, calendar: calendar))
        // Closing a shift on 16 Oct that runs into the night shift.
        enter(model, day: 16, start: date(16, 20))
        #expect(!model.canSetEnd(date(17, 23), onDay: day(16), now: now, calendar: calendar))
        #expect(model.canSetEnd(date(17, 22), onDay: day(16), now: now, calendar: calendar))
    }

    @Test func overlapWithTheActiveShiftIsRejected() {
        let model = DayLogModel()
        model.setDayStart(date(18, 23))
        #expect(model.isShiftOpen)
        #expect(!model.canSetStart(date(18, 23, 30), onDay: day(18), now: now, calendar: calendar))
        #expect(!model.canSetEnd(date(19, 1), onDay: day(18), now: now, calendar: calendar), "no record on the 18th yet; end alone sits inside the active shift")
        #expect(model.canSetStart(date(18, 8), onDay: day(18), now: now, calendar: calendar))
        enter(model, day: 18, start: date(18, 8))
        #expect(model.canSetEnd(date(18, 23), onDay: day(18), now: now, calendar: calendar))
        #expect(!model.canSetEnd(date(18, 23, 1), onDay: day(18), now: now, calendar: calendar))
    }

    // MARK: - The active shift stays untouched

    @Test func pastEntriesNeverChangeTheActiveShift() {
        let model = DayLogModel()
        model.setDayStart(date(19, 5))
        let id = model.dutyID
        enter(model, day: 17, start: date(17, 6), end: date(17, 14), driving: 300)
        enter(model, day: 17, start: date(17, 7))
        #expect(model.dutyID == id)
        #expect(model.dayStart == date(19, 5))
        #expect(model.isShiftOpen)
        #expect(model.dayEnd == nil && model.drivingMinutes == nil)
        #expect(model.shiftElapsedSeconds(at: now) == 7 * 3600)
        #expect(model.dayRecord(on: day(19), calendar: calendar) == nil, "the open shift is Home today, not a past record")
    }

    @Test func startOfDayCannotPrecedeAnEnteredPastShift() {
        let model = DayLogModel()
        enter(model, day: 18, start: date(18, 6), end: date(18, 20))
        #expect(!model.canStartShift(at: date(18, 19), now: now))
        #expect(model.canStartShift(at: date(18, 20), now: now))
    }

    // MARK: - Rest taken

    @Test func restTakenIsNextStartMinusEnd() throws {
        let model = DayLogModel()
        enter(model, day: 16, start: date(16, 6), end: date(16, 15, 30))
        enter(model, day: 17, start: date(17, 7, 45), end: date(17, 16))
        let rest = try #require(model.restTaken(after: model.dayRecord(on: day(16), calendar: calendar), now: now))
        #expect(rest.start == date(16, 15, 30))
        #expect(rest.end == date(17, 7, 45))
        #expect(HomeTimeline.clockDuration(seconds: rest.seconds) == "16:15")
    }

    @Test func restOfTheLatestClosedShiftRunsUpToNow() throws {
        let model = DayLogModel()
        enter(model, day: 18, start: date(18, 6), end: date(18, 16))
        let rest = try #require(model.restTaken(after: model.dayRecord(on: day(18), calendar: calendar), now: now))
        #expect(rest.end == nil)
        #expect(HomeTimeline.clockDuration(seconds: rest.seconds) == "20:00")
    }

    @Test func restUsesTheActiveShiftStartAsTheNextShift() throws {
        let model = DayLogModel()
        enter(model, day: 18, start: date(18, 6), end: date(18, 16))
        model.setDayStart(date(19, 4))
        let rest = try #require(model.restTaken(after: model.dayRecord(on: day(18), calendar: calendar), now: now))
        #expect(rest.end == date(19, 4))
        #expect(HomeTimeline.clockDuration(seconds: rest.seconds) == "12:00")
    }

    @Test func noRestWithoutDayClosed() {
        let model = DayLogModel()
        enter(model, day: 18, start: date(18, 6))
        #expect(model.restTaken(after: model.dayRecord(on: day(18), calendar: calendar), now: now) == nil)
        #expect(model.restTaken(after: nil, now: now) == nil)
    }

    // MARK: - The closed current shift is also a past day

    @Test func closedCurrentShiftShowsOnItsStartDayAndEditsThroughHomeCommands() throws {
        let model = DayLogModel()
        model.setDayStart(date(18, 6))
        model.closeShift(at: date(18, 16))
        let id = model.dutyID
        let record = try #require(model.dayRecord(on: day(18), calendar: calendar))
        #expect(record.id == id)
        #expect(model.restTaken(after: record, now: now)?.seconds == 20 * 3600)

        enter(model, day: 18, driving: 410)
        enter(model, day: 18, end: date(18, 17))
        #expect(model.drivingMinutes == 410)
        #expect(model.dayEnd == date(18, 17))
        #expect(model.currentRestStart == date(18, 17), "the running rest moved with Day closed")
        #expect(model.archivedPeriods.isEmpty)
        #expect(model.dutyID == id)
    }

    // MARK: - Persistence

    @Test func enteredAndEditedDaysSurviveRelaunchAndKeepStoredData() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "day-history-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "shifts.store")
        let activeID = try autoreleasepool { () throws -> UUID in
            let model = DayLogModel(storageURL: url)
            model.setDayStart(date(19, 5))
            model.setDrivingMinutes(60)
            enter(model, day: 17, start: date(17, 6), end: date(17, 14), driving: 300)
            enter(model, day: 18, driving: 90)
            enter(model, day: 17, end: date(17, 15))
            try #require(model.storageError == nil)
            return model.dutyID
        }
        try autoreleasepool {
            let reloaded = DayLogModel(storageURL: url)
            #expect(reloaded.storageError == nil)
            #expect(reloaded.dutyID == activeID)
            #expect(reloaded.dayStart == date(19, 5) && reloaded.drivingMinutes == 60 && reloaded.isShiftOpen)
            let seventeenth = reloaded.dayRecord(on: day(17), calendar: calendar)
            #expect(seventeenth?.start == date(17, 6) && seventeenth?.end == date(17, 15) && seventeenth?.drivingMinutes == 300)
            let eighteenth = reloaded.dayRecord(on: day(18), calendar: calendar)
            #expect(eighteenth?.drivingMinutes == 90 && eighteenth?.start == nil)
            #expect(reloaded.archivedPeriods.count == 2)
            #expect(reloaded.archivedPeriods.map { DayHistory.recordDay($0, calendar: calendar) } == [day(17), day(18)])
        }
    }

    @Test func startingANewShiftKeepsArchivedRecordsInOrder() {
        let model = DayLogModel()
        enter(model, day: 17, start: date(17, 6), end: date(17, 14))
        model.setDayStart(date(18, 6))
        model.closeShift(at: date(18, 14))
        model.startNewShift(at: date(19, 5), dailyRestConfirmed: true)
        #expect(model.archivedPeriods.compactMap(\.start) == [date(17, 6), date(18, 6)])
    }
}
