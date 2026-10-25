import Foundation
import Testing
@testable import TachoBook

/// The always-visible beds (Rest) and hammers (Work) row on Home, today and on past days
/// (owner decisions of 23.10.2026). The week is the owner's own device records of 14–24.10.2026,
/// rounded to the minute, in Europe/Berlin.
@MainActor
struct HomeCountRowTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func day(_ day: Int) -> Date { date(day, 0) }

    /// Shifts as (start, Day closed): weekly rest 20.10 12:31 → 21.10 12:51 (24 h 20), then a reduced rest
    /// ending 22.10 (9 h 08), a regular one ending 23.10 (13 h 04) and a reduced one ending 24.10 (9 h 12).
    private var shifts: [(Date, Date)] {
        [(date(14, 6, 4), date(14, 20, 54)), (date(15, 6, 4), date(15, 18, 36)), (date(16, 5, 47), date(16, 18, 35)),
         (date(17, 5, 40), date(17, 8, 34)), (date(19, 5, 40), date(19, 11, 45)), (date(20, 5, 47), date(20, 12, 31)),
         (date(21, 12, 51), date(21, 23, 48)), (date(22, 8, 56), date(22, 17, 24)), (date(23, 6, 28), date(23, 20, 27)),
         (date(24, 5, 39), date(24, 19, 17))]
    }

    /// The records up to and including shift `last`, closed with its rest; with `open` the last shift is still running.
    private func model(through last: Int, open: Bool = false) -> DayLogModel {
        let periods = shifts.prefix(last + 1).enumerated().map { index, shift in
            let next = index < last ? shifts[index + 1].0 : nil
            return DutyPeriod(date: shift.0, start: shift.0, end: shift.1, isClosed: true,
                              rests: [RestSegment(start: shift.1, end: next, dailyRestConfirmed: next.map { _ in true },
                                                  kind: .daily)])
        }
        let model = DayLogModel(date: shifts[last].0)
        model.update { journal in
            journal.history = Array(periods.dropLast())
            journal.current = open ? DutyPeriod(date: shifts[last].0, start: shifts[last].0) : periods[last]
        }
        return model
    }

    // MARK: - Root cause (owner report of 23.10.2026)

    /// 23.10 at 08:00 the driver is 1 h 32 into a shift after one reduced rest. Before the fix Home took the
    /// Work card's row from the pending-reduction value, which is nil for the first 13 h of every shift, and
    /// the Rest view is disabled during a shift: the beds were gone although the count (1) was known.
    @Test func theRowShowsTheKnownCountDuringTheFirstThirteenHoursOfAShift() {
        let model = model(through: 8, open: true)
        let now = date(23, 8)
        #expect(model.reducedRestsUsed == 1)
        #expect(model.homeReducedRests(now: now) == 1)
    }

    /// Past days never received a count, so the date strip showed no beds on any day.
    @Test func aPastDayShowsTheCountItHadAtTheEndOfThatDay() {
        let model = model(through: 9)
        let now = date(24, 21)
        // 20.10: the weekly rest is still running at midnight; 21.10: the rest after its shift is still running.
        #expect(model.reducedRests(endOf: day(20), now: now, calendar: calendar) == 0)
        #expect(model.reducedRests(endOf: day(21), now: now, calendar: calendar) == 0)
        // 22.10: the 9 h 08 rest ended at 08:56 — the first reduction.
        #expect(model.reducedRests(endOf: day(22), now: now, calendar: calendar) == 1)
        // 23.10: a 13 h 59 shift — the second reduction is already certain at the end of the day.
        #expect(model.reducedRests(endOf: day(23), now: now, calendar: calendar) == 2)
    }

    // MARK: - Today

    @Test func restAndWorkViewsShowTheSameCountToday() {
        // 24.10 21:00: resting after a 13 h 38 shift (pending), two reductions completed.
        let model = model(through: 9)
        let now = date(24, 21)
        #expect(model.isResting)
        #expect(model.homeReducedRests(now: now) == 3)
        #expect(model.homeReducedRests(now: now) == model.restCardReducedRests(now: now))
        #expect(model.homeReducedRests(now: now) == model.workCardReducedRests(now: now))
        // The stored count changes only when the rest ends.
        #expect(model.reducedRestsUsed == 2)
    }

    @Test func todayWithoutAWeeklyRestInTheRecordsIsUnknown() {
        let model = model(through: 2, open: true)
        #expect(model.homeReducedRests(now: date(16, 8)) == nil)
        #expect(model.dutyLimitAvailability == .unknown)
    }

    // MARK: - Past days

    @Test func aPastDayBeforeAnyWeeklyRestIsUnknown() {
        let model = model(through: 9)
        #expect(model.reducedRests(endOf: day(16), now: date(24, 21), calendar: calendar) == nil)
    }

    @Test func aPastDayCountIgnoresLaterRecords() {
        // The same 22.10 whether it is viewed on 23.10 or on 24.10.
        let earlier = model(through: 8, open: true).reducedRests(endOf: day(22), now: date(23, 8), calendar: calendar)
        let later = model(through: 9).reducedRests(endOf: day(22), now: date(24, 21), calendar: calendar)
        #expect(earlier == 1)
        #expect(later == 1)
    }

    @Test func aDayWithoutAShiftShowsTheCountOfTheRestCoveringIt() {
        // 18.10 has no shift and the 45 h weekly rest from 17.10 is still running at midnight: still unknown.
        // 19.10: that weekly rest has ended, so the count starts at 0.
        let model = model(through: 9)
        #expect(model.reducedRests(endOf: day(18), now: date(24, 21), calendar: calendar) == nil)
        #expect(model.reducedRests(endOf: day(19), now: date(24, 21), calendar: calendar) == 0)
    }

    @Test func editingAPastDayRecomputesTheDaysAfterIt() {
        let model = model(through: 9)
        let now = date(24, 21)
        // Day closed of 21.10 corrected from 23:48 to 21:00: the rest becomes 11 h 56, regular (R-E01).
        model.setEnd(date(21, 21), onDay: day(21), now: now, calendar: calendar)
        #expect(model.reducedRests(endOf: day(22), now: now, calendar: calendar) == 0)
        #expect(model.reducedRests(endOf: day(23), now: now, calendar: calendar) == 1)
        #expect(model.homeReducedRests(now: now) == 2)
    }

    // MARK: - Accessibility labels

    @Test func labelsNameBedsAndHammers() {
        #expect(ReducedRestRow.label(icon: .bed, used: 1) == "1 of 3 reduced rests used")
        #expect(ReducedRestRow.label(icon: .hammer, used: 1) == "1 of 3 extended shifts used")
        #expect(ReducedRestRow.label(icon: .hammer, used: 4) == "4 extended shifts used, limit 3")
        #expect(ReducedRestRow.label(icon: .bed, used: nil) == "Reduced rests used: unknown")
        #expect(ReducedRestRow.label(icon: .hammer, used: nil) == "Extended shifts used: unknown")
    }

    @Test func unknownShowsNoUsedIcon() {
        #expect(ReducedRestRow.usedIcons(used: nil) == 0)
        #expect(ReducedRestRow.usedIcons(used: 2) == 2)
        #expect(ReducedRestRow.usedIcons(used: 4) == 3)
    }
}
