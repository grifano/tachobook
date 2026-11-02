import Foundation
import Testing
@testable import TachoBook

/// A shift past 13 h always uses a reduction, also when the rest after it leaves less than 9 h in its window,
/// and three used reductions leave only 13 h / 11 h (owner decisions 1–5, 30.10.2026). Europe/Berlin.
@MainActor
struct ReductionAfterShortRestTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private let hour: TimeInterval = 3600

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
    }

    private func day(_ day: Int) -> Date { date(day, 0) }

    private func pause(_ start: Date, _ end: Date, confirmed: Bool? = true) -> RestSegment {
        RestSegment(start: start, end: end, dailyRestConfirmed: confirmed, kind: .daily)
    }

    private func period(_ start: Date, _ end: Date? = nil, pauses: [RestSegment] = []) -> DutyPeriod {
        DutyPeriod(date: start, start: start, end: end, isClosed: end != nil, rests: pauses)
    }

    /// A shift and a 46 h weekly rest, then `used` days of 12 h duty with a 10 h (reduced) rest, ending at `anchor`.
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

    /// The completed count once the rest after the duty period `anchor → restStart` has ended at `restEnd`.
    private func count(used: Int, anchor: Date, restStart: Date, restEnd: Date, pauses: [RestSegment] = []) -> Int? {
        ReducedRestCounter.usedCount(periods: history(used: used, endingAt: anchor)
            + [period(anchor, restStart, pauses: pauses), period(restEnd)])
    }

    // MARK: - Counter (decision 1)

    @Test func thirteenOhOneWithAReducedRestUsesOne() {
        let anchor = date(12, 6)
        #expect(count(used: 0, anchor: anchor, restStart: date(12, 19, 1), restEnd: date(13, 5, 30)) == 1)
    }

    /// 16:16 of duty, 7:43 of rest inside the window (Serhii's 29.10): a shortfall, and still one reduction.
    @Test func sixteenSixteenWithSevenFortyThreeInTheWindowUsesOne() {
        let anchor = date(12, 5, 13, 30)
        let restStart = date(12, 21, 30)
        let restEnd = date(13, 6, 37)
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: [], restStart: restStart, restEnd: restEnd) == .shortfall)
        #expect(count(used: 0, anchor: anchor, restStart: restStart, restEnd: restEnd) == 1)
        #expect(count(used: 2, anchor: anchor, restStart: restStart, restEnd: restEnd) == 3)
    }

    @Test func upToThirteenHoursWithElevenHoursOfRestUsesNone() {
        let anchor = date(12, 6)
        #expect(count(used: 0, anchor: anchor, restStart: date(12, 19), restEnd: date(13, 6)) == 0)
    }

    /// A short shift with a short rest stays a shortfall without a reduction: decision 1 is about duty past 13 h.
    @Test func aShortShiftWithAShortRestUsesNone() {
        let anchor = date(12, 6)
        #expect(count(used: 1, anchor: anchor, restStart: date(12, 18), restEnd: date(13, 2)) == 1)
    }

    @Test func aConfirmedSplitFirstPauseUsesNone() {
        let anchor = date(12, 6)
        let pauses = [pause(date(12, 10), date(12, 13))]
        // 3 h + 9 h: a regular split.
        #expect(count(used: 1, anchor: anchor, restStart: date(12, 21), restEnd: date(13, 6), pauses: pauses) == 1)
        // 3 h, then less than 9 h inside the window: a shortfall, but no reduction either.
        #expect(count(used: 1, anchor: anchor, restStart: date(12, 22), restEnd: date(13, 6), pauses: pauses) == 1)
        // An unconfirmed pause is no split: the long shift uses a reduction.
        let unconfirmed = [pause(date(12, 10), date(12, 13), confirmed: nil)]
        #expect(count(used: 1, anchor: anchor, restStart: date(12, 22), restEnd: date(13, 6), pauses: unconfirmed) == 2)
    }

    /// At 3 of 3 a further long shift is a deviation (Violation Counter Task): the row shows no 4th icon.
    @Test func countAlreadyThreeStaysThree() {
        let anchor = date(12, 6)
        let model = DayLogModel(date: anchor)
        model.update { journal in
            journal.history = history(used: 3, endingAt: anchor) + [period(anchor, date(12, 21, 30))]
            journal.current = period(date(13, 6, 37))
        }
        let shown = model.homeReducedRests(now: date(13, 8))
        #expect(shown == 4)
        #expect(ReducedRestRow.usedIcons(used: shown) == 3)
    }

    // MARK: - Serhii's week of 26–30.10.2026 (owner report 30.10.2026)

    /// Weekly rest until Mon 26.10 05:00; reduced rests after 26.10 and 27.10, a regular one after 28.10; the
    /// 29.10 shift 05:13 → 21:30, then rest until the new shift on 30.10 06:37 (7:43 inside the window).
    private func ownerWeek(openOn30: Bool = true) -> DayLogModel {
        let shifts: [(Date, Date)] = [
            (date(23, 6), date(23, 18)),           // then the weekly rest until 26.10 05:00
            (date(26, 5), date(26, 17)),           // rest 10 h → 27.10 03:00: reduced
            (date(27, 3), date(27, 15)),           // rest 10 h → 28.10 01:00: reduced
            (date(28, 1), date(28, 13)),           // rest → 29.10 05:13: regular
            (date(29, 5, 13, 30), date(29, 21, 30)),
        ]
        let starts = shifts.map(\.0) + [date(30, 6, 37)]
        let periods = shifts.enumerated().map { index, shift in
            DutyPeriod(date: shift.0, start: shift.0, end: shift.1, isClosed: true,
                       rests: [RestSegment(start: shift.1, end: starts[index + 1], dailyRestConfirmed: true,
                                           kind: index == 0 ? .weekly : .daily)])
        }
        let model = DayLogModel(date: day(30))
        model.update { journal in
            journal.history = periods
            journal.current = period(date(30, 6, 37))
        }
        if !openOn30 { model.closeShift(at: date(30, 17)) }
        return model
    }

    /// Root cause: the 29.10 rest is a shortfall in its window, which the counter skipped, so the reduction
    /// that 29.10 showed during its shift and rest disappeared when the 30.10 shift started.
    @Test func theTwentyNinthKeepsItsReductionOnTheThirtieth() {
        let model = ownerWeek()
        let now = date(30, 8)
        #expect(model.reducedRestsUsed == 3)
        #expect(model.homeReducedRests(now: now) == 3)
        // Day summary of 29.10 and its calendar bed.
        #expect(model.historyReducedRests(onDay: day(29), now: now, calendar: calendar) == 3)
        #expect(model.historyMarkers(on: day(29), now: now, calendar: calendar).contains(.reducedRest))
        #expect(model.reducedRests(endOf: day(29), now: now, calendar: calendar) == 3)
        let beds = (26...30).filter { model.historyMarkers(on: day($0), now: now, calendar: calendar).contains(.reducedRest) }
        #expect(beds == [26, 27, 29])
        // 13 h / 11 h for the 30.10 shift.
        #expect(model.dutyLimitAvailability == .thirteenHoursOnly)
    }

    @Test func theCountStaysThreeUntilTheNextWeeklyRest() {
        let model = ownerWeek(openOn30: false)
        #expect(model.homeReducedRests(now: date(31, 2)) == 3)
        #expect(model.dutyLimitAvailability == .thirteenHoursOnly)
        // A weekly rest after 30.10 starts a new count.
        model.startShift(at: date(31, 17), now: date(31, 17))
        #expect(model.reducedRestsUsed == 0)
        #expect(model.dutyLimitAvailability == .fifteenHours)
    }

    // MARK: - 13 h / 11 h at 3 of 3 (decisions 4–5)

    @Test func threeOfThreeWithoutSplitShowsOnlyThirteenAndEleven() {
        let limits = ReducedRestCounter.availability(used: 3, period: period(date(12, 6)))
        #expect(HomeTimeline.dutyGaugeHours(limits) == 13)
        #expect(HomeTimeline.shownDutyMarkerHours(limits) == [13])
        #expect(HomeTimeline.dailyRestRequiredHours(limits) == 11)
        #expect(HomeTimeline.shownDailyRestMilestoneHours(limits) == [11])
    }

    @Test func aConfirmedSplitOrTwoUsedKeepFifteenAndNine() {
        let split = ReducedRestCounter.availability(used: 3, period: period(date(12, 6), pauses: [pause(date(12, 10), date(12, 13))]))
        let two = ReducedRestCounter.availability(used: 2, period: period(date(12, 6)))
        let unknown = ReducedRestCounter.availability(used: nil, period: period(date(12, 6)))
        for limits in [split, two, unknown] {
            #expect(HomeTimeline.dutyGaugeHours(limits) == 15)
            #expect(HomeTimeline.shownDutyMarkerHours(limits) == [13, 15])
            #expect(HomeTimeline.dailyRestRequiredHours(limits) == 9)
            #expect(HomeTimeline.shownDailyRestMilestoneHours(limits) == [9, 11])
        }
    }

    /// The last-hour warning counts down to the applicable marker: 13 h at 3 of 3.
    @Test func theWarningCountsDownToTheApplicableMarker() {
        let start = date(12, 6)
        #expect(HomeTimeline.dutyRemainingSeconds(shiftStart: start, at: date(12, 18, 30), limitHours: 13) == 1800)
        #expect(HomeTimeline.isDutyWarning(shiftStart: start, at: date(12, 18, 30), limitHours: 13))
        #expect(!HomeTimeline.isDutyWarning(shiftStart: start, at: date(12, 18, 30)))
    }
}
