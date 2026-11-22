import Foundation
import Testing
@testable import TachoBook

/// The No activities widget on a past day without a shift (Figma 838:33650), in Europe/Berlin.
/// "Now" is Monday 19 October 2026 12:00; days back 1…3 are 18, 17 and 16 October.
@MainActor
struct NoActivitiesDayTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private var now: Date { date(19, 12) }
    private func day(_ number: Int) -> Date { calendar.startOfDay(for: date(number, 0)) }

    private func enter(_ model: DayLogModel, day number: Int, start: Date, end: Date, driving: Int? = nil) {
        model.setStart(start, onDay: day(number), now: now, calendar: calendar)
        model.setEnd(end, onDay: day(number), now: now, calendar: calendar)
        if let driving { model.setDriving(minutes: driving, onDay: day(number), calendar: calendar) }
    }

    @Test func aPastDayWithoutARecordShowsTheWidget() throws {
        let model = DayLogModel()
        enter(model, day: 16, start: date(16, 5, 40), end: date(16, 8, 34), driving: 128)
        let empty = try #require(model.noActivitiesDay(onDay: day(17), now: now, calendar: calendar))
        #expect(empty.lastShift?.start == date(16, 5, 40))
        #expect(empty.lastShift?.drivingMinutes == 128)
    }

    @Test func aDayWithARecordShowsNoWidget() {
        let model = DayLogModel()
        enter(model, day: 17, start: date(17, 6), end: date(17, 14))
        #expect(model.noActivitiesDay(onDay: day(17), now: now, calendar: calendar) == nil)
    }

    @Test func todayNeverShowsTheWidget() {
        let model = DayLogModel()
        enter(model, day: 16, start: date(16, 6), end: date(16, 14))
        #expect(model.noActivitiesDay(onDay: day(19), now: now, calendar: calendar) == nil)
        #expect(model.noActivitiesDay(onDay: day(20), now: now, calendar: calendar) == nil, "nor the future")
    }

    @Test func aDayBetweenTwoShiftsPicksTheOneBefore() throws {
        let model = DayLogModel()
        enter(model, day: 15, start: date(15, 6), end: date(15, 14))
        enter(model, day: 16, start: date(16, 7), end: date(16, 15))
        enter(model, day: 18, start: date(18, 7), end: date(18, 15))
        let empty = try #require(model.noActivitiesDay(onDay: day(17), now: now, calendar: calendar))
        #expect(empty.lastShift?.start == date(16, 7), "the 16th, not the 15th or the later 18th")
    }

    @Test func withoutAnEarlierShiftOnlyTheTopPartShows() throws {
        let empty = try #require(DayLogModel().noActivitiesDay(onDay: day(17), now: now, calendar: calendar))
        #expect(empty.lastShift == nil)
        #expect(empty.target(now: now, calendar: calendar) == nil, "nothing to open")
        // A shift only after the day is not an earlier one.
        let model = DayLogModel()
        enter(model, day: 18, start: date(18, 7), end: date(18, 15))
        #expect(try #require(model.noActivitiesDay(onDay: day(17), now: now, calendar: calendar)).lastShift == nil)
    }

    @Test func whileTheRestIsStillRunningTheClosedShiftIsTheLastActivity() throws {
        // The shift of the 16th is closed on Home and its rest still runs.
        let model = DayLogModel()
        model.setDayStart(date(16, 6))
        model.closeShift(at: date(16, 14, 30))
        #expect(model.isResting)
        for number in [17, 18] {
            let empty = try #require(model.noActivitiesDay(onDay: day(number), now: now, calendar: calendar))
            #expect(empty.lastShift?.end == date(16, 14, 30))
        }
        #expect(model.noActivitiesDay(onDay: day(16), now: now, calendar: calendar) == nil, "the 16th has the shift")
    }

    @Test func aShiftAcrossMidnightIsTheLastActivityOfTheNextDay() throws {
        let model = DayLogModel()
        enter(model, day: 16, start: date(16, 22), end: date(17, 6))
        let empty = try #require(model.noActivitiesDay(onDay: day(17), now: now, calendar: calendar))
        #expect(empty.lastShift?.start == date(16, 22))
    }

    @Test func aDayWhereTheOpenShiftStartedIsNotEmpty() {
        let model = DayLogModel()
        model.setDayStart(date(18, 22))
        #expect(model.isShiftOpen)
        #expect(model.noActivitiesDay(onDay: day(18), now: now, calendar: calendar) == nil)
    }

    @Test func aLastShiftWithinThreeDaysOpensOnHomeAnOlderOneInHistory() throws {
        let recent = DayLogModel()
        enter(recent, day: 16, start: date(16, 6), end: date(16, 14))
        let near = try #require(recent.noActivitiesDay(onDay: day(18), now: now, calendar: calendar))
        #expect(near.target(now: now, calendar: calendar) == .home(daysBack: 3))

        let old = DayLogModel()
        enter(old, day: 10, start: date(10, 6), end: date(10, 14))
        let far = try #require(old.noActivitiesDay(onDay: day(18), now: now, calendar: calendar))
        #expect(far.target(now: now, calendar: calendar) == .history(day: day(10)))
    }

    @Test func addOnHomePreselectsTheViewedDay() {
        // Home starts the past-shift flow with the viewed day; the start sheet opens on that day at the current time.
        let request = PastShiftRequest(day: day(17))
        let draft = PastShiftDraft(day: request.day, now: now, calendar: calendar)
        #expect(calendar.isDate(draft.start, inSameDayAs: day(17)))
        #expect(draft.start == date(17, 12))
    }

    @Test func theLastActivityDateReadsLikeFigma() {
        #expect(HomeTimeline.lastActivityDate(date(16, 5), calendar: calendar) == "Fr, 16 Oct 2026", "the device locale's order and punctuation")
    }
}
