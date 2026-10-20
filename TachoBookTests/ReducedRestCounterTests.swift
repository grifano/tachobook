import Foundation
import Testing
@testable import TachoBook

/// Reduced daily rest counter (R-D02–R-D05) against the specification scenarios, in Europe/Berlin.
/// A is the end of the previous rest, recorded as the start of the duty period.
@MainActor
struct ReducedRestCounterTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private let hour: TimeInterval = 3600

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func pause(_ start: Date, _ end: Date, confirmed: Bool? = true) -> RestSegment {
        RestSegment(start: start, end: end, dailyRestConfirmed: confirmed, kind: .daily)
    }

    private func period(_ start: Date, _ end: Date? = nil, pauses: [RestSegment] = []) -> DutyPeriod {
        DutyPeriod(date: start, start: start, end: end, isClosed: end != nil, rests: pauses)
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

    /// History, the scenario's duty period (A → final rest start) and the next shift that ends the rest.
    private func count(used: Int, anchor: Date, restStart: Date, restEnd: Date, pauses: [RestSegment] = []) -> Int? {
        ReducedRestCounter.usedCount(periods: history(used: used, endingAt: anchor)
            + [period(anchor, restStart, pauses: pauses), period(restEnd)])
    }

    // MARK: - Specification scenarios

    @Test func v01RegularRestKeepsTheCount() {
        let anchor = date(12, 6)
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: [], restStart: date(12, 19), restEnd: date(13, 6)) == .regular)
        #expect(count(used: 0, anchor: anchor, restStart: date(12, 19), restEnd: date(13, 6)) == 0)
        let milestones = HomeTimeline.restMilestones(restStart: date(12, 19), kind: .daily)
        #expect(milestones.first == date(13, 4))
        #expect(milestones.second == date(13, 6))
    }

    @Test func v02ExactlyNineHoursIsTheThirdReduction() {
        let anchor = date(12, 6)
        let open = history(used: 2, endingAt: anchor) + [period(anchor)]
        #expect(ReducedRestCounter.usedCount(periods: open) == 2)
        let availability = ReducedRestCounter.availability(used: 2, period: period(anchor))
        #expect(availability == .fifteenHours)
        // 21:00 is still an allowed final rest start.
        #expect(availability.latestRestStartHours.map { HomeTimeline.adding(hours: $0, to: anchor) } == date(12, 21))
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: [], restStart: date(12, 21), restEnd: date(13, 6)) == .reduced)
        #expect(count(used: 2, anchor: anchor, restStart: date(12, 21), restEnd: date(13, 6)) == 3)
    }

    @Test func v03ElevenHoursWithOnlyTenInTheWindowIsReduced() {
        let anchor = date(12, 6)
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: [], restStart: date(12, 20), restEnd: date(13, 7)) == .reduced)
        #expect(count(used: 0, anchor: anchor, restStart: date(12, 20), restEnd: date(13, 7)) == 1)
    }

    @Test func v04ShortfallIsNotAReduction() {
        let anchor = date(12, 6)
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: [], restStart: date(12, 21, 1), restEnd: date(13, 8, 1)) == .shortfall)
        #expect(count(used: 1, anchor: anchor, restStart: date(12, 21, 1), restEnd: date(13, 8, 1)) == 1)
    }

    @Test func v05ThreeReductionsWithoutSplitLeaveOnlyThirteenHours() {
        let anchor = date(12, 6)
        let open = history(used: 3, endingAt: anchor) + [period(anchor)]
        let used = ReducedRestCounter.usedCount(periods: open)
        #expect(used == 3)
        let availability = ReducedRestCounter.availability(used: used, period: period(anchor))
        #expect(availability == .thirteenHoursOnly)
        #expect(availability.latestRestStartHours.map { HomeTimeline.adding(hours: $0, to: anchor) } == date(12, 19))
        // Resting 21:00 → 06:00 anyway records a fourth reduction; the count is not capped.
        #expect(count(used: 3, anchor: anchor, restStart: date(12, 21), restEnd: date(13, 6)) == 4)
    }

    @Test func v06ConfirmedThreePlusNineIsARegularSplit() {
        let anchor = date(12, 6)
        let pauses = [pause(date(12, 12), date(12, 15))]
        let open = period(anchor, pauses: pauses)
        #expect(ReducedRestCounter.availability(used: 3, period: open) == .fifteenHours)
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: pauses, restStart: date(12, 21), restEnd: date(13, 6)) == .split)
        #expect(count(used: 3, anchor: anchor, restStart: date(12, 21), restEnd: date(13, 6), pauses: pauses) == 3)
    }

    @Test func v07TwoFiftyNineIsNotASplitFirstPart() {
        let anchor = date(12, 6)
        let pauses = [pause(date(12, 12), date(12, 14, 59))]
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: pauses, restStart: date(12, 21), restEnd: date(13, 6)) == .reduced)
        #expect(count(used: 2, anchor: anchor, restStart: date(12, 21), restEnd: date(13, 6), pauses: pauses) == 3)
    }

    @Test func v08UnconfirmedPauseNeverConfirmsASplit() {
        let anchor = date(12, 6)
        let pauses = [pause(date(12, 12), date(12, 15), confirmed: nil)]
        #expect(ReducedRestCounter.availability(used: 3, period: period(anchor, pauses: pauses)) == .unknown)
        #expect(ReducedRestCounter.classify(anchor: anchor, pauses: pauses, restStart: date(12, 21), restEnd: date(13, 6)) == .reduced)
    }

    @Test func v12RunningRestIsNotCountedAtNineHours() {
        let anchor = date(12, 6)
        let model = DayLogModel(date: anchor)
        model.update { journal in
            journal.history = history(used: 1, endingAt: anchor)
            journal.current = period(anchor)
        }
        model.closeShift(at: date(12, 19))
        // 04:00: 9 h reached, the rest is still running and provisional; no duty is created.
        #expect(model.restElapsedSeconds(at: date(13, 4)) == 9 * 3600)
        #expect(model.isResting)
        #expect(model.reducedRestsUsed == 1)
        // 06:00: 11 h in the window, regular; the count stays 1.
        model.startShift(at: date(13, 6), now: date(13, 6))
        #expect(model.isShiftOpen)
        #expect(model.reducedRestsUsed == 1)
    }

    @Test func v34NewInstallIsUnknownNotZero() {
        let model = DayLogModel(date: date(12, 6))
        #expect(model.reducedRestsUsed == nil)
        #expect(model.dutyLimitAvailability == .unknown)
        model.setDayStart(date(12, 6))
        model.closeShift(at: date(12, 18))
        #expect(model.isResting)
        #expect(model.reducedRestsUsed == nil)
        #expect(model.dutyLimitAvailability == .unknown)
    }

    @Test func v36MondayDoesNotResetTheCount() {
        // 12.10.2026 is a Monday; the third reduced rest ends on Monday 19.10 06:00.
        let monday = date(19, 6)
        let periods = history(used: 3, endingAt: monday) + [period(monday)]
        #expect(calendar.component(.weekday, from: monday) == 2)
        #expect(ReducedRestCounter.usedCount(periods: periods) == 3)
    }

    // MARK: - Boundaries and unknown states

    @Test(arguments: [(23 * 3600 + 59 * 60, false), (24 * 3600, true), (45 * 3600, true)])
    func aCompletedRestOfTwentyFourHoursResetsTheCount(seconds: Int, isWeekly: Bool) {
        let anchor = date(12, 6)
        let restStart = date(12, 18)
        let restEnd = restStart.addingTimeInterval(TimeInterval(seconds))
        #expect((ReducedRestCounter.classify(anchor: anchor, pauses: [], restStart: restStart, restEnd: restEnd) == .weekly) == isWeekly)
        let used = count(used: 3, anchor: anchor, restStart: restStart, restEnd: restEnd)
        #expect(used == (isWeekly ? 0 : 3))
    }

    @Test func noWeeklyRestInTheRecordsIsUnknown() {
        let periods = [period(date(12, 6), date(12, 18)), period(date(13, 5), date(13, 17)), period(date(14, 5))]
        #expect(ReducedRestCounter.usedCount(periods: periods) == nil)
        #expect(ReducedRestCounter.availability(used: nil, period: period(date(14, 5))) == .unknown)
    }

    @Test func aRecordWithoutEndAfterTheWeeklyRestMakesTheCountUnknown() {
        let anchor = date(14, 6)
        var periods = history(used: 1, endingAt: anchor)
        periods.append(period(anchor)) // Day closed never entered.
        periods.append(period(date(15, 6)))
        #expect(ReducedRestCounter.usedCount(periods: periods) == nil)
    }

    @Test func driverOnlyEntriesWithoutTimesAreIgnored() {
        let anchor = date(14, 6)
        let drivingOnly = DutyPeriod(date: date(13, 0), drivingMinutes: 300)
        #expect(ReducedRestCounter.usedCount(periods: history(used: 2, endingAt: anchor) + [drivingOnly, period(anchor)]) == 2)
    }

    @Test func availabilityFollowsTheCountInAllThreeStates() {
        let open = period(date(12, 6))
        #expect(ReducedRestCounter.availability(used: 0, period: open) == .fifteenHours)
        #expect(ReducedRestCounter.availability(used: 2, period: open) == .fifteenHours)
        #expect(ReducedRestCounter.availability(used: 3, period: open) == .thirteenHoursOnly)
        #expect(ReducedRestCounter.availability(used: nil, period: open) == .unknown)
        // A confirmed split-first part allows 15 h even when the count is unknown.
        let split = period(date(12, 6), pauses: [pause(date(12, 9), date(12, 12))])
        #expect(ReducedRestCounter.availability(used: nil, period: split) == .fifteenHours)
    }

    @Test func accessibilityLabelSaysHowManyAreUsed() {
        #expect(ReducedRestRow.label(used: 2) == "2 of 3 reduced rests used")
        #expect(ReducedRestRow.label(used: 0) == "0 of 3 reduced rests used")
        #expect(ReducedRestRow.label(used: 4) == "4 reduced rests used, limit 3")
    }

    // MARK: - Pending reduction on the Work card (decisions 12–13)

    /// A model with a weekly rest, `used` reduced rests and an open shift from 12.10 06:00.
    private func openShiftModel(used: Int?, pauses: [RestSegment] = []) -> DayLogModel {
        let anchor = date(12, 6)
        let model = DayLogModel(date: anchor)
        model.update { journal in
            journal.history = used.map { history(used: $0, endingAt: anchor) } ?? [period(date(11, 6), date(11, 18))]
            journal.current = period(anchor, pauses: pauses)
        }
        return model
    }

    @Test func thirteenHoursExactlyShowsNoPendingBed() {
        let model = openShiftModel(used: 1)
        #expect(model.workCardReducedRests(now: date(12, 19)) == nil)
        #expect(model.workCardReducedRests(now: date(12, 18, 59)) == nil)
    }

    @Test func thirteenOhOneShowsOneMoreRedBed() {
        let model = openShiftModel(used: 1)
        #expect(model.workCardReducedRests(now: date(12, 19, 1)) == 2)
        // The stored count is unchanged until the rest ends.
        #expect(model.reducedRestsUsed == 1)
    }

    @Test func confirmedSplitFirstPauseMeansNoPendingBed() {
        let model = openShiftModel(used: 1, pauses: [pause(date(12, 10), date(12, 13))])
        #expect(model.workCardReducedRests(now: date(12, 19, 1)) == nil)
        // An unconfirmed pause does not prevent it.
        let unconfirmed = openShiftModel(used: 1, pauses: [pause(date(12, 10), date(12, 13), confirmed: nil)])
        #expect(unconfirmed.workCardReducedRests(now: date(12, 19, 1)) == 2)
    }

    @Test func completedCountThreeAddsNoFourthBed() {
        let model = openShiftModel(used: 3)
        #expect(model.workCardReducedRests(now: date(12, 19, 1)) == 3)
    }

    @Test func unknownCountHidesTheWorkCardRow() {
        let model = openShiftModel(used: nil)
        #expect(model.reducedRestsUsed == nil)
        #expect(model.workCardReducedRests(now: date(12, 20)) == nil)
    }

    @Test func historyEditBackToThirteenHoursRemovesThePendingBed() {
        let model = openShiftModel(used: 0)
        let now = date(12, 20)
        #expect(model.workCardReducedRests(now: now) == 1)
        // Day started corrected from 06:00 to 07:00: 13 h of duty at 20:00, no longer past 13 h.
        model.editDayStart(date(12, 7), now: now)
        #expect(model.dayStart == date(12, 7))
        #expect(model.workCardReducedRests(now: now) == nil)
    }

    @Test func closedShiftKeepsThePendingBedUntilTheRestEnds() {
        let model = openShiftModel(used: 0)
        model.closeShift(at: date(12, 20))
        // Work tab while resting: duty is judged at its close time.
        #expect(model.workCardReducedRests(now: date(13, 2)) == 1)
        #expect(model.reducedRestsUsed == 0)
        // Day closed corrected to 19:00: duty 13 h, no pending bed.
        model.editDayEnd(date(12, 19), now: date(13, 2))
        #expect(model.workCardReducedRests(now: date(13, 2)) == nil)
        // Back to 20:00; the rest then ends at 05:00 (9 h in the window): the pending bed became the stored count.
        model.editDayEnd(date(12, 20), now: date(13, 2))
        #expect(model.workCardReducedRests(now: date(13, 2)) == 1)
        model.startShift(at: date(13, 5), now: date(13, 5))
        #expect(model.reducedRestsUsed == 1)
    }

    @Test func restCardShowsThePendingBedOnlyAfterAShiftPastThirteenHours() {
        // 14 h shift: red already during the rest.
        let long = openShiftModel(used: 1)
        long.closeShift(at: date(12, 20))
        #expect(long.restCardReducedRests(now: date(12, 21)) == 2)
        #expect(long.reducedRestsUsed == 1)
        // 12 h shift, then a 9 h rest: red only once the rest has ended.
        let short = openShiftModel(used: 1)
        short.closeShift(at: date(12, 18))
        #expect(short.restCardReducedRests(now: date(13, 3)) == 1)
        short.startShift(at: date(13, 3), now: date(13, 3))
        #expect(short.reducedRestsUsed == 2)
        // Unknown count: still hidden.
        let unknown = openShiftModel(used: nil)
        unknown.closeShift(at: date(12, 20))
        #expect(unknown.restCardReducedRests(now: date(12, 21)) == nil)
    }

    @Test func aRunningRestOfTwentyFourHoursEndsThePendingBed() {
        let model = openShiftModel(used: 2)
        model.closeShift(at: date(12, 20))
        #expect(model.workCardReducedRests(now: date(13, 19, 59)) == 3)
        #expect(model.workCardReducedRests(now: date(13, 20)) == nil)
    }

    // MARK: - Model: history edits (R-E01) and relaunch

    @Test func editingAPastDayRecomputesTheCount() throws {
        let now = date(16, 12)
        let model = DayLogModel(date: now)
        // Weekly rest, then a 10 h rest from 13.10 18:00 to 14.10 04:00, then the shift of 14.10.
        model.update { journal in
            journal.history = [period(date(10, 6), date(10, 14)), period(date(12, 6), date(12, 18)),
                               period(date(13, 6), date(13, 18)), period(date(14, 4), date(14, 14))]
            journal.current = period(date(15, 6))
        }
        #expect(model.reducedRestsUsed == 1)
        // Day started on 14.10 corrected to 05:00: 11 h inside the window, regular.
        model.setStart(date(14, 5), onDay: date(14, 0), now: now, calendar: calendar)
        try #require(model.dayRecord(on: date(14, 0), calendar: calendar)?.start == date(14, 5))
        #expect(model.reducedRestsUsed == 0)
    }

    @Test func theCountSurvivesARelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "reduced-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "shifts.store")
        let now = date(20, 12)
        autoreleasepool {
            let model = DayLogModel(storageURL: url)
            model.seedReducedRestsIfEmpty(used: 2, restElapsed: 3600, now: now)
            #expect(model.reducedRestsUsed == 2)
        }
        try autoreleasepool {
            let model = DayLogModel(storageURL: url)
            try #require(model.storageError == nil)
            #expect(model.reducedRestsUsed == 2)
            #expect(model.isResting)
        }
    }
}
