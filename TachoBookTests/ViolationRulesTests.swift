import Foundation
import Testing
@testable import TachoBook

/// Deviation counter (owner decisions 1, 14–19, 19.10–07.11.2026) against the specification scenarios
/// (V04, V05, V09, V10), in Europe/Berlin. A is the duty period's start (the end of the previous rest).
@MainActor
struct ViolationRulesTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private let hour: TimeInterval = 3600

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func period(_ start: Date?, _ end: Date? = nil, pauses: [RestSegment] = []) -> DutyPeriod {
        DutyPeriod(date: start ?? end ?? Date(), start: start, end: end, isClosed: end != nil, rests: pauses)
    }

    private func pause(_ start: Date, _ end: Date, confirmed: Bool? = true) -> RestSegment {
        RestSegment(start: start, end: end, dailyRestConfirmed: confirmed, kind: .daily)
    }

    /// A completed 46 h weekly rest and then `used` reduced rests (12 h duty, 10 h rest), the last ending at `anchor`.
    private func history(used: Int, endingAt anchor: Date) -> [DutyPeriod] {
        var periods: [DutyPeriod] = []
        var next = anchor
        for _ in 0..<used {
            let start = next.addingTimeInterval(-22 * hour)
            periods.insert(period(start, start.addingTimeInterval(12 * hour)), at: 0)
            next = start
        }
        let weeklyStart = next.addingTimeInterval(-46 * hour)
        periods.insert(period(weeklyStart.addingTimeInterval(-8 * hour), weeklyStart), at: 0)
        return periods
    }

    /// `periods` with the last one as the current record.
    private func model(_ periods: [DutyPeriod]) -> DayLogModel {
        DayLogModel(journal: ShiftJournal(current: periods.last!, history: Array(periods.dropLast())))
    }

    private func violations(_ periods: [DutyPeriod], now: Date) -> [Violation] {
        ViolationRules.violations(periods: periods, currentID: periods.last!.id, now: now, calendar: calendar)
    }

    // MARK: - Duty period beyond the applicable limit (R-D05)

    @Test func v05FourthReductionPassesTheThirteenHourLimit() throws {
        // used = 3, no split, A = 12.10 06:00: the latest final rest start is 19:00.
        let anchor = date(12, 6)
        let shift = period(anchor, date(12, 19, 30))
        let found = violations(history(used: 3, endingAt: anchor) + [shift, period(date(13, 6))], now: date(13, 7))
        let duty = try #require(found.first { $0.kind == .dutyLimit })
        #expect(duty.key.periodID == shift.id)
        #expect(duty.limitHours == 13)
        #expect(duty.began == date(12, 19))
        #expect(duty.overtimeSeconds == 30 * 60)
        #expect(duty.day == calendar.startOfDay(for: anchor))
        #expect(!duty.isOngoing)
    }

    @Test func closingExactlyAtTheLimitIsNotADeviation() {
        let anchor = date(12, 6)
        let found = violations(history(used: 3, endingAt: anchor) + [period(anchor, date(12, 19)), period(date(13, 6))],
                               now: date(13, 7))
        #expect(found.isEmpty)
    }

    @Test func fifteenHoursApplyWhileAReductionIsLeft() throws {
        let anchor = date(12, 6)
        let within = violations(history(used: 2, endingAt: anchor) + [period(anchor, date(12, 21))], now: date(12, 22))
        #expect(within.isEmpty, "15 h at 2 of 3: 15:00 is still allowed")
        let past = violations(history(used: 2, endingAt: anchor) + [period(anchor, date(12, 21, 1))], now: date(12, 22))
        let duty = try #require(past.first)
        #expect(duty.limitHours == 15)
        #expect(duty.overtimeSeconds == 60)
    }

    @Test func confirmedSplitKeepsFifteenHoursAtThreeOfThree() {
        let anchor = date(12, 6)
        let split = period(anchor, date(12, 20), pauses: [pause(date(12, 9), date(12, 12))])
        #expect(violations(history(used: 3, endingAt: anchor) + [split], now: date(12, 21)).isEmpty)
        let unconfirmed = period(anchor, date(12, 20), pauses: [pause(date(12, 9), date(12, 12), confirmed: nil)])
        // An unconfirmed pause leaves 13 vs 15 h open: unknown between them, never a deviation (R-U01).
        #expect(violations(history(used: 3, endingAt: anchor) + [unconfirmed], now: date(12, 21)).isEmpty)
    }

    @Test func unknownCountIsOnlyCertainPastFifteenHours() throws {
        // No weekly rest in the records: the count is unknown.
        let anchor = date(12, 6)
        #expect(violations([period(anchor, date(12, 20))], now: date(12, 21)).isEmpty)
        let past = try #require(violations([period(anchor, date(12, 22))], now: date(12, 23)).first)
        #expect(past.limitHours == 15)
        #expect(past.overtimeSeconds == 3600)
    }

    @Test func openShiftPastTheLimitIsOngoingAndGrows() throws {
        let anchor = date(12, 6)
        let periods = history(used: 3, endingAt: anchor) + [period(anchor)]
        #expect(violations(periods, now: date(12, 19)).isEmpty)
        let early = try #require(violations(periods, now: date(12, 19, 30)).first)
        #expect(early.isOngoing)
        #expect(early.overtimeSeconds == 30 * 60)
        let later = try #require(violations(periods, now: date(12, 21)).first)
        #expect(later.overtimeSeconds == 2 * 3600)
        #expect(later.key == early.key, "the same violation, so its printout follows it")
    }

    @Test func archivedShiftWithoutCloseIsUnknown() {
        let anchor = date(12, 6)
        // A start without a close on an earlier day: incomplete, not a deviation.
        let found = violations([period(anchor), period(date(14, 6))], now: date(14, 7))
        #expect(found.isEmpty)
    }

    // MARK: - Daily rest under 9 h in its window (R-D02, R-D07)

    @Test func v04RestShortOfNineHoursByOneMinute() throws {
        // A = 12.10 06:00; rest 21:01 → 13.10 08:01: only 8:59 before D = 13.10 06:00.
        let anchor = date(12, 6)
        let shift = period(anchor, date(12, 21, 1))
        let found = violations(history(used: 1, endingAt: anchor) + [shift, period(date(13, 8, 1))], now: date(13, 9))
        let rest = try #require(found.first { $0.kind == .shortRest })
        #expect(rest.restSeconds == 8 * 3600 + 59 * 60)
        #expect(rest.began == date(12, 21, 1))
        #expect(rest.limitHours == 9)
        #expect(rest.key == ViolationKey(periodID: shift.id, kind: .shortRest))
        // The late close also passes the 15 h limit by a minute: both rules are kept, each as recorded.
        #expect(found.contains { $0.kind == .dutyLimit && $0.overtimeSeconds == 60 })
    }

    @Test func shortRestAfterANormalShift() throws {
        let anchor = date(12, 6)
        let found = violations([period(anchor, date(12, 18)), period(date(13, 2))], now: date(13, 3))
        #expect(found.count == 1)
        let rest = try #require(found.first)
        #expect(rest.kind == .shortRest)
        #expect(rest.restSeconds == 8 * 3600)
    }

    @Test func nineHoursInTheWindowIsNotADeviation() {
        let anchor = date(12, 6)
        #expect(violations([period(anchor, date(12, 18)), period(date(13, 3))], now: date(13, 4)).isEmpty)
    }

    @Test func v09PauseBeforeResumeIsNotARest() {
        // Start 06:00; close 12:00; resume 15:00; close 19:00. One duty period of 13 h; final rest from 19:00.
        let shift = period(date(12, 6), date(12, 19), pauses: [pause(date(12, 12), date(12, 15), confirmed: nil)])
        let found = violations(history(used: 0, endingAt: date(12, 6)) + [shift, period(date(13, 4))], now: date(13, 5))
        #expect(found.isEmpty, "the 3 h pause is not a short rest and 13 h is within 15 h")
    }

    @Test func v10ShortPauseAndLateCloseLeaveEightFiftyFive() throws {
        // A = 06:00; close 20:45; resume 20:50; close 21:05; used = 1.
        let anchor = date(12, 6)
        let shift = period(anchor, date(12, 21, 5), pauses: [pause(date(12, 20, 45), date(12, 20, 50), confirmed: nil)])
        let current = history(used: 1, endingAt: anchor) + [shift]
        // While the rest runs before D (13.10 06:00) its classification is provisional.
        let duringRest = violations(current, now: date(13, 5))
        #expect(duringRest.map(\.kind) == [.dutyLimit], "15:05 of duty passed the 15 h limit")
        #expect(duringRest.first?.overtimeSeconds == 5 * 60)
        // Once D has passed, 8:55 inside the window is final; the 9 h count from 21:05, not 20:45.
        let rest = try #require(violations(current, now: date(13, 6, 1)).first { $0.kind == .shortRest })
        #expect(rest.restSeconds == 8 * 3600 + 55 * 60)
        #expect(rest.began == date(12, 21, 5))
    }

    @Test func restRunningIntoWeeklyIsJudgedInItsWindow() throws {
        // Close at A + 16 h, then a 30 h rest: only 8 h of it are inside the window.
        let anchor = date(12, 6)
        let found = violations([period(anchor, date(12, 22)), period(date(14, 4))], now: date(14, 5))
        let rest = try #require(found.first { $0.kind == .shortRest })
        #expect(rest.restSeconds == 8 * 3600)
    }

    @Test func newestFirst() {
        let found = violations([period(date(10, 6), date(10, 22)), period(date(11, 8), date(11, 18)), period(date(12, 1))],
                               now: date(12, 2))
        #expect(found.map(\.began) == found.map(\.began).sorted(by: >))
        #expect(found.count == 3)
    }

    // MARK: - Recomputed after history edits (R-E01) and printouts

    @Test func historyEditRemovesAndRestoresTheViolationWithItsPrintout() throws {
        let anchor = date(12, 6)
        let periods = history(used: 3, endingAt: anchor) + [period(anchor)]
        let model = model(periods)
        let now = date(12, 19, 30)
        let violation = try #require(model.violations(now: now, calendar: calendar).first)
        model.markPrintout(now, for: violation, now: now)
        #expect(model.printout(for: violation.key) == now)

        // Editing the start later brings the duty within 13 h: no violation, the printout is kept.
        model.editDayStart(date(12, 7), now: now)
        #expect(model.violations(now: now, calendar: calendar).isEmpty)
        model.editDayStart(anchor, now: now)
        let back = try #require(model.violations(now: now, calendar: calendar).first)
        #expect(back.key == violation.key)
        #expect(model.printout(for: back.key) == now)
    }

    @Test func printoutTimeLimits() throws {
        let anchor = date(12, 6)
        let model = model(history(used: 3, endingAt: anchor) + [period(anchor, date(12, 20))])
        let now = date(13, 9)
        let violation = try #require(model.violations(now: now, calendar: calendar).first)
        #expect(model.checkPrintout(date(12, 18, 59), for: violation, now: now) == .printoutTooEarly(date(12, 19), .dutyLimit))
        #expect(model.checkPrintout(date(12, 19), for: violation, now: now) == nil)
        #expect(model.checkPrintout(now, for: violation, now: now) == nil)
        #expect(model.checkPrintout(now.addingTimeInterval(60), for: violation, now: now) == .future)

        model.markPrintout(date(12, 18), for: violation, now: now)
        #expect(model.printout(for: violation.key) == nil, "an invalid time is never saved")
        model.markPrintout(date(12, 21), for: violation, now: now)
        #expect(model.printout(for: violation.key) == date(12, 21))
        model.clearPrintout(for: violation.key)
        #expect(model.printout(for: violation.key) == nil)
    }

    @Test func printoutReasonLines() {
        let began = date(19, 18, 40)
        let limit = TimeEntryIssue.printoutTooEarly(began, .dutyLimit).message(calendar: calendar)
        #expect(limit?.hasPrefix("Pick a time after your limit passed (") == true)
        let rest = TimeEntryIssue.printoutTooEarly(began, .shortRest).message(calendar: calendar)
        #expect(rest?.hasPrefix("Pick a time after your rest started (") == true)
    }

    // MARK: - Time sheets over the limit (decision 14)

    @Test func closingLateShowsTheRedLineForThirteenHours() {
        let anchor = date(12, 6)
        let model = model(history(used: 3, endingAt: anchor) + [period(anchor)])
        let now = date(12, 20)
        func line(closingAt close: Date) -> String? {
            DayLogModel.overLimitLine(model.dutyViolation(previewing: { $0.closeShift(at: close, now: now) },
                                                          periodID: { $0.dutyID }, now: now))
        }
        #expect(line(closingAt: date(12, 19)) == nil)
        #expect(line(closingAt: date(12, 19, 30)) == "This shift passes your 13-hour limit by 0:30.")
        #expect(model.dayEnd == nil, "the preview never changes the saved shift")
    }

    @Test func fifteenHourAndUnknownRedLines() {
        let anchor = date(12, 6)
        let now = date(13, 0)
        let twoOfThree = model(history(used: 2, endingAt: anchor) + [period(anchor)])
        let unknown = model([period(anchor)])
        for model in [twoOfThree, unknown] {
            func line(_ close: Date) -> String? {
                DayLogModel.overLimitLine(model.dutyViolation(previewing: { $0.closeShift(at: close, now: now) },
                                                              periodID: { $0.dutyID }, now: now))
            }
            #expect(line(date(12, 20)) == nil, "between 13 h and 15 h: within 15 h, or unknown")
            #expect(line(date(12, 21, 15)) == "This shift passes your 15-hour limit by 0:15.")
        }
    }

    @Test func editingAStartEarlierPushesAnOpenShiftPastTheLimit() {
        // The previous rest (20:00 → 06:00) stays reduced after the edit (20:00 → 05:00), so 13 h apply.
        let anchor = date(12, 6)
        let model = model(history(used: 3, endingAt: anchor) + [period(anchor)])
        let now = date(12, 18, 30)
        let line = DayLogModel.overLimitLine(model.dutyViolation(previewing: { $0.editDayStart(date(12, 5), now: now) },
                                                                 periodID: { $0.dutyID }, now: now))
        #expect(line == "This shift passes your 13-hour limit by 0:30.")
        #expect(model.dayStart == anchor)
    }

    // MARK: - 56-day carry period (decisions 15–17)

    @Test func daysLeftFromThePrintoutDay() {
        let printed = date(19, 21, 15)
        func status(on now: Date) -> PrintoutCarry.Status {
            PrintoutCarry.status(violationDay: date(19, 0), printedAt: printed, now: now, calendar: calendar)
        }
        #expect(status(on: date(19, 23)).daysLeft == 56)
        #expect(status(on: date(19, 23)).carryUntil == date(14, 0, month: 12))
        #expect(status(on: date(2, 12, month: 11)).daysLeft == 42)
        #expect(status(on: date(14, 23, 59, month: 12)).daysLeft == 0)
        #expect(!status(on: date(14, 23, 59, month: 12)).isOlder)
        #expect(status(on: date(15, 0, 1, month: 12)).isOlder, "the day after carryUntil")
    }

    @Test func counterUpdatesAtMidnight() {
        let printed = date(19, 10)
        let before = PrintoutCarry.status(violationDay: date(19, 0), printedAt: printed, now: date(19, 23, 59), calendar: calendar)
        let after = PrintoutCarry.status(violationDay: date(19, 0), printedAt: printed, now: date(20, 0, 1), calendar: calendar)
        #expect(before.daysLeft == 56)
        #expect(after.daysLeft == 55)
    }

    @Test func printoutOnALaterDayCountsFromThatDay() {
        // A short rest from 18 Oct, printed two days later.
        let status = PrintoutCarry.status(violationDay: date(18, 0), printedAt: date(20, 8), now: date(20, 9), calendar: calendar)
        #expect(status.daysLeft == 56)
        #expect(status.carryUntil == date(15, 0, month: 12))
    }

    @Test func missingPrintoutShowsAQuestionMarkAndMovesAfterFiftySixDays() {
        let day = date(19, 0)
        let last = PrintoutCarry.status(violationDay: day, printedAt: nil, now: date(14, 22, month: 12), calendar: calendar)
        #expect(last.daysLeft == nil)
        #expect(last.carryUntil == nil)
        #expect(!last.isOlder)
        let next = PrintoutCarry.status(violationDay: day, printedAt: nil, now: date(15, 1, month: 12), calendar: calendar)
        #expect(next.isOlder)
        #expect(next.daysLeft == nil, "keeps \"?\"")
        // A printout entered now brings the row back with the counter.
        let entered = PrintoutCarry.status(violationDay: day, printedAt: date(15, 1, month: 12), now: date(15, 2, month: 12),
                                           calendar: calendar)
        #expect(!entered.isOlder)
        #expect(entered.daysLeft == 56)
        // An earlier printout whose carryUntil has passed keeps it in the gray group.
        let old = PrintoutCarry.status(violationDay: day, printedAt: date(19, 22), now: date(15, 2, month: 12), calendar: calendar)
        #expect(old.isOlder)
    }
}
