import Foundation
import Testing
@testable import TachoBook

/// Editing a past day from the History Day summary (Add Past Shift task, iteration 2, decision 8, 16.11.2026). The
/// sheet uses the same commands as Home's earlier days; these tests pin what History relies on.
@MainActor
struct HistoryEditTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func day(_ day: Int) -> Date { date(day, 0) }

    /// 16.11.2026 18:00: the edited days below are 12 or more days back, past Home's 3-day swipe.
    private var now: Date { date(16, 18) }

    /// Closed shifts, each followed by its rest up to the next start; the last one is current, in its running rest
    /// (or, with `openLast`, still open).
    private func model(_ shifts: [(Date, Date)], openLast: Bool = false) -> DayLogModel {
        let periods = shifts.enumerated().map { index, shift in
            let next = index + 1 < shifts.count ? shifts[index + 1].0 : nil
            return DutyPeriod(date: shift.0, start: shift.0, drivingMinutes: 300, end: shift.1, isClosed: true,
                              rests: [RestSegment(start: shift.1, end: next, dailyRestConfirmed: next.map { _ in true },
                                                  kind: .daily)])
        }
        let model = DayLogModel(date: now)
        model.update { journal in
            journal.history = Array(periods.dropLast())
            var current = periods[periods.count - 1]
            if openLast {
                current.end = nil
                current.isClosed = false
                current.rests = []
            }
            journal.current = current
        }
        return model
    }

    /// A weekly rest after 01.11 (count known from 03.11), a 10 h shift on 03.11 with an 11 h rest up to 04.11 03:00,
    /// and the 04.11 shift whose rest still runs.
    private var week: DayLogModel {
        model([(date(1, 6), date(1, 14)), (date(3, 6), date(3, 16)), (date(4, 3), date(4, 13))])
    }

    @Test func anEditFromHistoryRecomputesTheReducedRestMarker() {
        let model = week
        #expect(model.historyMarkers(now: now, calendar: calendar)[day(3)]?.contains(.reducedRest) != true)

        // Day closed one hour later: the rest up to 04.11 03:00 is 10 h, a reduced rest on the shift day.
        #expect(model.canSetEnd(date(3, 17), onDay: day(3), now: now, calendar: calendar))
        model.setEnd(date(3, 17), onDay: day(3), now: now, calendar: calendar)
        #expect(model.historyRecord(on: day(3), calendar: calendar)?.end == date(3, 17))
        #expect(model.historyMarkers(now: now, calendar: calendar)[day(3)]?.contains(.reducedRest) == true)
        #expect(model.historyReducedRests(onDay: day(3), now: now, calendar: calendar) == 1)

        // Back to 16:00: the bed is gone again.
        model.setEnd(date(3, 16), onDay: day(3), now: now, calendar: calendar)
        #expect(model.historyMarkers(now: now, calendar: calendar)[day(3)]?.contains(.reducedRest) != true)
        #expect(model.historyReducedRests(onDay: day(3), now: now, calendar: calendar) == 0)
    }

    @Test func editingADayOlderThanThreeDaysWorksForEveryField() {
        let model = week
        #expect(DayHistory.daysBack(of: day(3), from: now, calendar: calendar) == nil, "outside Home's swipe")
        #expect(model.canEditHistoryDay(day(3), calendar: calendar))
        model.setStart(date(3, 7), onDay: day(3), now: now, place: ShiftPlace(country: "D"), calendar: calendar)
        model.setDriving(minutes: 420, onDay: day(3), calendar: calendar)
        model.setEnd(date(3, 15), onDay: day(3), now: now, place: ShiftPlace(country: "F"), calendar: calendar)
        let record = model.historyRecord(on: day(3), calendar: calendar)
        #expect(record?.start == date(3, 7))
        #expect(record?.drivingMinutes == 420)
        #expect(record?.end == date(3, 15))
        #expect(record?.startPlace == ShiftPlace(country: "D"))
        #expect(record?.endPlace == ShiftPlace(country: "F"))
    }

    @Test func invalidEditsShowAReasonAndChangeNothing() {
        let model = week
        // Into the next shift, before the start, in the future.
        #expect(model.checkSetEnd(date(4, 4), onDay: day(3), now: now, calendar: calendar)
            == .overlap(from: date(4, 3), to: date(4, 13)))
        #expect(model.checkSetEnd(date(3, 5), onDay: day(3), now: now, calendar: calendar)
            == .endBeforeStart(start: date(3, 6)))
        #expect(model.checkSetEnd(date(16, 19), onDay: day(3), now: now, calendar: calendar) == .future)
        model.setEnd(date(4, 4), onDay: day(3), now: now, calendar: calendar)
        #expect(model.historyRecord(on: day(3), calendar: calendar)?.end == date(3, 16), "nothing overwritten")
    }

    @Test func anEditThatCreatesADeviationIsFound() throws {
        let model = week
        let before = Set(model.violations(now: now, calendar: calendar).map(\.key))
        #expect(before.isEmpty)
        // 06:00–22:00 passes the 15 h limit, and leaves a 5 h rest before 04.11 03:00.
        model.setEnd(date(3, 22), onDay: day(3), now: now, calendar: calendar)
        let first = try #require(model.firstNewViolation(since: before, now: now, calendar: calendar))
        #expect(first.kind == .dutyLimit)
        #expect(first.day == day(3))
        // Nothing new the second time.
        let after = Set(model.violations(now: now, calendar: calendar).map(\.key))
        #expect(model.firstNewViolation(since: after, now: now, calendar: calendar) == nil)
    }

    @Test func editingAPastDayLeavesTheOpenShiftAlone() throws {
        let model = model([(date(3, 6), date(3, 16)), (date(16, 6), date(16, 14))], openLast: true)
        #expect(model.isShiftOpen)
        let id = model.dutyID
        model.setEnd(date(3, 17), onDay: day(3), now: now, calendar: calendar)
        model.setDriving(minutes: 200, onDay: day(3), calendar: calendar)
        #expect(model.historyRecord(on: day(3), calendar: calendar)?.end == date(3, 17))
        #expect(model.dutyID == id)
        #expect(model.isShiftOpen)
        #expect(model.dayStart == date(16, 6))
        #expect(model.dayEnd == nil)
        #expect(model.drivingMinutes == 300)
        #expect(model.shiftElapsedSeconds(at: now) == 12 * 3600, "the live timer is unchanged")
    }

    @Test func whichDaysTheSummaryCanEdit() {
        let open = model([(date(3, 6), date(3, 16)), (date(16, 6), date(16, 14))], openLast: true)
        #expect(open.canEditHistoryDay(day(3), calendar: calendar))
        #expect(!open.canEditHistoryDay(day(16), calendar: calendar), "the running shift, as on Home")
        #expect(!open.canEditHistoryDay(day(10), calendar: calendar), "an empty day stays as it is (decision 9)")

        // Today's shift in its rest is edited like on Home.
        let resting = model([(date(3, 6), date(3, 16)), (date(16, 6), date(16, 14))])
        #expect(resting.isResting)
        #expect(resting.canEditHistoryDay(day(16), calendar: calendar))
        resting.setEnd(date(16, 15), onDay: day(16), now: now, calendar: calendar)
        #expect(resting.dayEnd == date(16, 15))
        #expect(resting.currentRestStart == date(16, 15), "the running rest moves with Day closed, as on Home")
    }
}
