import Foundation
import Testing
@testable import TachoBook

/// Add past shift (owner decision 5, 16.11.2026): a shift for an earlier day entered through the normal shift flow.
@MainActor
struct PastShiftTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func day(_ day: Int) -> Date { date(day, 0) }

    /// 16.11.2026 18:00.
    private var now: Date { date(16, 18) }

    /// Closed shifts, each followed by its rest up to the next start; the last one is current, in its running rest.
    private func model(_ shifts: [(Date, Date)]) -> DayLogModel {
        let model = DayLogModel(date: now)
        guard !shifts.isEmpty else { return model }
        let periods = shifts.enumerated().map { index, shift in
            let next = index + 1 < shifts.count ? shifts[index + 1].0 : nil
            return DutyPeriod(date: shift.0, start: shift.0, drivingMinutes: 300, end: shift.1, isClosed: true,
                              rests: [RestSegment(start: shift.1, end: next, dailyRestConfirmed: next.map { _ in true },
                                                  kind: .daily)])
        }
        model.update { journal in
            journal.history = Array(periods.dropLast())
            journal.current = periods[periods.count - 1]
        }
        return model
    }

    private func draft(_ start: Date, _ end: Date, place: String = "PL") -> PastShiftDraft {
        var draft = PastShiftDraft(now: now, calendar: calendar)
        draft.start = start
        draft.end = end
        draft.startPlace = ShiftPlace(country: place)
        draft.endPlace = ShiftPlace(country: place)
        return draft
    }

    private func shifts(on day: Date, in model: DayLogModel) -> [DutyPeriod] {
        (model.state.history + [model.state.current])
            .filter { $0.start != nil && DayHistory.recordDay($0, calendar: calendar) == day }
    }

    // MARK: - Saved like a normal shift

    @Test func aBackfilledShiftAppearsInTheCalendarMarkers() {
        let model = model([(date(14, 6), date(14, 16)), (date(15, 6), date(15, 16))])
        #expect(model.historyMarkers(now: now, calendar: calendar)[day(10)] == nil)
        let entry = draft(date(10, 5), date(10, 17))
        #expect(model.savePastShift(entry, drivingMinutes: 570, now: now, calendar: calendar))
        #expect(model.historyMarkers(now: now, calendar: calendar)[day(10)]?.contains(.extendedDriving) == true)
        let saved = model.dayRecord(on: day(10), calendar: calendar)
        #expect(saved?.id == entry.id)
        #expect(saved?.isClosed == true)
        #expect(saved?.startPlace == ShiftPlace(country: "PL"))
        #expect(saved?.drivingMinutes == 570)
        // The current shift stays current.
        #expect(model.state.current.start == date(15, 6))
        #expect(model.isResting)
    }

    @Test func aBackfilledShiftPastItsLimitAppearsInViolations() throws {
        let model = model([(date(14, 6), date(14, 16)), (date(15, 6), date(15, 16))])
        // 16 h with the count unknown: only past 15 h is certain (R-U01).
        let entry = draft(date(10, 5), date(10, 21))
        #expect(model.savePastShift(entry, drivingMinutes: 480, now: now, calendar: calendar))
        let violation = try #require(model.pastShiftViolation(id: entry.id, now: now, calendar: calendar))
        #expect(violation.kind == .dutyLimit)
        #expect(violation.day == day(10))
        #expect(model.violations(now: now, calendar: calendar).contains { $0.key == violation.key })
        #expect(model.historyMarkers(now: now, calendar: calendar)[day(10)]?.contains(.violation) == true)
        // Older than 56 days goes to the gray group (decision 17), as for any violation.
        #expect(!model.carryStatus(of: violation, now: now, calendar: calendar).isOlder)
    }

    @Test func aShiftWithinItsLimitHasNoViolationToShow() {
        let model = model([(date(15, 6), date(15, 16))])
        let entry = draft(date(10, 6), date(10, 14))
        #expect(model.savePastShift(entry, drivingMinutes: 300, now: now, calendar: calendar))
        #expect(model.pastShiftViolation(id: entry.id, now: now, calendar: calendar) == nil)
    }

    @Test func theCloseSheetWarnsBeforeTheLimitIsPassed() {
        let model = model([(date(15, 6), date(15, 16))])
        var entry = PastShiftDraft(now: now, calendar: calendar)
        entry.start = date(10, 5)
        #expect(model.pastShiftOverLimitLine(entry, end: date(10, 21), now: now)
            == "This shift passes your 15-hour limit by 1:00.")
        #expect(model.pastShiftOverLimitLine(entry, end: date(10, 14), now: now) == nil)
        #expect(model.state.history.isEmpty, "the preview saves nothing")
    }

    // MARK: - One shift per day, replace on overlap

    @Test func aShiftOnTheSameDayOrOverlappingAsksToReplace() {
        let model = model([(date(12, 6), date(12, 16)), (date(15, 6), date(15, 16))])
        let existing = model.state.history[0].id
        // The same day, even without overlap.
        #expect(model.pastShiftConflicts(start: date(12, 18), end: nil, now: now, calendar: calendar).map(\.id) == [existing])
        // A start inside the shift.
        #expect(model.pastShiftConflicts(start: date(12, 10), end: nil, now: now, calendar: calendar).map(\.id) == [existing])
        // A shift from the evening before that runs into it.
        #expect(model.pastShiftConflicts(start: date(11, 22), end: date(12, 7), now: now, calendar: calendar)
            .map(\.id) == [existing])
        // Touching edges do not collide.
        #expect(model.pastShiftConflicts(start: date(11, 20), end: date(12, 6), now: now, calendar: calendar).isEmpty)
    }

    @Test func nothingIsOverwrittenWithoutReplaceAndReplaceLeavesOneShift() {
        let model = model([(date(12, 6), date(12, 16)), (date(15, 6), date(15, 16))])
        let existing = model.state.history[0].id
        var entry = draft(date(12, 8), date(12, 18))
        #expect(!model.savePastShift(entry, drivingMinutes: 300, now: now, calendar: calendar))
        #expect(shifts(on: day(12), in: model).map(\.id) == [existing])

        entry.replacing = [existing]
        #expect(model.savePastShift(entry, drivingMinutes: 300, now: now, calendar: calendar))
        let left = shifts(on: day(12), in: model)
        #expect(left.map(\.id) == [entry.id])
        #expect(left.first?.end == date(12, 18))
    }

    @Test func replacingAPrintoutsShiftRemovesItsPrintout() throws {
        let model = model([(date(12, 5), date(12, 21)), (date(15, 6), date(15, 16))])
        let old = try #require(model.violations(now: now, calendar: calendar).first { $0.kind == .dutyLimit })
        model.markPrintout(date(12, 22), for: old, now: now)
        var entry = draft(date(12, 6), date(12, 14))
        entry.replacing = [old.key.periodID]
        #expect(model.savePastShift(entry, drivingMinutes: 300, now: now, calendar: calendar))
        #expect(model.printout(for: old.key) == nil)
    }

    @Test func theOpenShiftCollidesAndCanBeReplaced() {
        let model = DayLogModel(date: now)
        model.update { $0.current = DutyPeriod(date: date(16, 6), start: date(16, 6)) }
        #expect(model.isShiftOpen)
        let conflicts = model.pastShiftConflicts(start: date(16, 7), end: date(16, 9), now: now, calendar: calendar)
        #expect(conflicts.count == 1)
        #expect(conflicts.first?.end == nil, "the open shift has no end")
        var entry = draft(date(16, 7), date(16, 9))
        entry.replacing = Set(conflicts.map(\.id))
        #expect(model.savePastShift(entry, drivingMinutes: 60, now: now, calendar: calendar))
        #expect(model.state.current.id == entry.id)
        #expect(model.state.history.isEmpty)
    }

    @Test func replaceCopyNamesTheShift() {
        let conflict = PastShiftConflict(id: UUID(), start: date(12, 6), end: date(12, 16))
        let message = PastShiftCopy.replaceMessage([conflict], calendar: calendar)
        #expect(message.hasPrefix("You already have a shift from "))
        #expect(message.hasSuffix("Replace it with this one?"))
        #expect(PastShiftCopy.replaceMessage([conflict, conflict], calendar: calendar)
            == "This overlaps 2 of your shifts. Replace them with this one?")
        let open = PastShiftConflict(id: UUID(), start: date(16, 6), end: nil)
        #expect(PastShiftCopy.replaceMessage([open], calendar: calendar).hasPrefix("This overlaps your current shift from "))
    }

    // MARK: - Cancel saves nothing

    @Test func cancelOnAnyStepSavesNothing() {
        let model = model([(date(15, 6), date(15, 16))])
        let before = (model.state.history + [model.state.current]).map(\.id)
        var entry = PastShiftDraft(now: now, calendar: calendar)
        // Cancel on the start sheet: only the checks ran.
        entry.start = date(10, 6)
        _ = model.checkPastShiftStart(entry.start, now: now)
        _ = model.pastShiftConflicts(start: entry.start, end: nil, now: now, calendar: calendar)
        // Cancel on the close sheet: the checks and the over-limit preview ran.
        _ = model.checkPastShiftEnd(date(10, 14), start: entry.start, now: now)
        _ = model.pastShiftOverLimitLine(entry, end: date(10, 14), now: now)
        // Cancel on the driving sheet: the close is in the draft, but without driving the flow never saves; an
        // incomplete draft is refused anyway.
        #expect(!model.savePastShift(entry, drivingMinutes: 300, now: now, calendar: calendar), "no close yet")
        entry.end = date(10, 14)
        #expect((model.state.history + [model.state.current]).map(\.id) == before)
        #expect(model.state.current.start == date(15, 6))
    }

    @Test func invalidTimesAreRefused() {
        let model = model([(date(15, 6), date(15, 16))])
        #expect(model.checkPastShiftStart(date(16, 19), now: now) == .future)
        #expect(model.checkPastShiftEnd(date(10, 5), start: date(10, 6), now: now) == .endBeforeStart(start: date(10, 6)))
        #expect(model.checkPastShiftEnd(date(16, 19), start: date(16, 6), now: now) == .future)
        #expect(!model.savePastShift(draft(date(10, 6), date(10, 5)), drivingMinutes: 0, now: now, calendar: calendar))
        #expect(!model.savePastShift(draft(date(16, 17), date(16, 19)), drivingMinutes: 0, now: now, calendar: calendar))
        var spain = draft(date(10, 6), date(10, 14), place: "E")
        #expect(!model.savePastShift(spain, drivingMinutes: 0, now: now, calendar: calendar), "Spain needs a region")
        spain.startPlace = ShiftPlace(country: "E", region: "PV")
        spain.endPlace = ShiftPlace(country: "E", region: "PV")
        #expect(model.savePastShift(spain, drivingMinutes: 0, now: now, calendar: calendar))
    }

    // MARK: - Rest after a manual shift

    @Test func restAfterTheLastManualShiftIsUnknown() {
        // A fresh install: only the manual shift, 16 h past its limit, and nothing after it.
        let model = DayLogModel(date: now)
        let entry = draft(date(12, 5), date(12, 21))
        #expect(model.savePastShift(entry, drivingMinutes: 480, now: now, calendar: calendar))
        // It is the latest record, resting since its close as after a normal close.
        #expect(model.state.current.id == entry.id)
        #expect(model.isResting)
        #expect(model.currentRestStart == date(12, 21))
        // The rest is not judged: no short-rest deviation and no reduced-rest count.
        let kinds = model.violations(now: now, calendar: calendar).filter { $0.key.periodID == entry.id }.map(\.kind)
        #expect(kinds == [.dutyLimit])
        #expect(model.historyReducedRests(onDay: day(12), now: now, calendar: calendar) == nil)
    }

    @Test func aLaterManualShiftBecomesCurrentAndEndsTheRunningRest() {
        let model = model([(date(13, 6), date(13, 16))])
        let previous = model.state.current.id
        let entry = draft(date(15, 6), date(15, 14))
        #expect(model.savePastShift(entry, drivingMinutes: 300, now: now, calendar: calendar))
        #expect(model.state.current.id == entry.id)
        #expect(model.currentRestStart == date(15, 14))
        let archived = model.state.history.last
        #expect(archived?.id == previous)
        #expect(archived?.rests.last?.end == date(15, 6), "the earlier rest ends where the manual shift starts")
        // The rest between them is now measured: 38 h, no deviation.
        #expect(model.violations(now: now, calendar: calendar).isEmpty)
    }

    @Test func anEarlierManualShiftEndsTheRestOfTheShiftBeforeIt() {
        let model = model([(date(10, 6), date(10, 16)), (date(15, 6), date(15, 16))])
        let entry = draft(date(12, 6), date(12, 14))
        #expect(model.savePastShift(entry, drivingMinutes: 300, now: now, calendar: calendar))
        #expect(model.state.history.map(\.start) == [date(10, 6), date(12, 6)])
        #expect(model.state.history[0].rests.last?.end == date(12, 6))
        #expect(model.state.current.start == date(15, 6))
    }

    // MARK: - Preselected day (Home, next Task)

    @Test func aPreselectedDayOpensTheStartOnThatDayAndSavesOnIt() {
        let model = model([(date(15, 6), date(15, 16))])
        var entry = PastShiftDraft(day: day(13), now: now, calendar: calendar)
        #expect(calendar.isDate(entry.start, inSameDayAs: day(13)))
        #expect(entry.start == date(13, 18), "the time of day comes from now")
        entry.end = date(13, 23)
        entry.startPlace = ShiftPlace(country: "D")
        entry.endPlace = ShiftPlace(country: "D")
        #expect(model.savePastShift(entry, drivingMinutes: 120, now: now, calendar: calendar))
        #expect(model.dayRecord(on: day(13), calendar: calendar)?.id == entry.id)
        // Without a day it starts at now (History).
        #expect(PastShiftDraft(now: now, calendar: calendar).start == now)
        // A preselected today never starts in the future.
        #expect(PastShiftDraft(day: day(16), now: now, calendar: calendar).start == now)
    }
}
