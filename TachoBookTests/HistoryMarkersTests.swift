import Foundation
import Testing
@testable import TachoBook

/// History calendar markers and the Day summary sheet (MVP-07, owner decisions of 24.10.2026).
@MainActor
struct HistoryMarkersTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func day(_ day: Int) -> Date { date(day, 0) }

    /// Closed shifts (start, Day closed, driving minutes), each followed by its rest up to the next start.
    /// The last one is the current record, in its running rest.
    private func model(_ shifts: [(Date, Date, Int?)]) -> DayLogModel {
        let periods = shifts.enumerated().map { index, shift in
            let next = index + 1 < shifts.count ? shifts[index + 1].0 : nil
            return DutyPeriod(date: shift.0, start: shift.0, drivingMinutes: shift.2, end: shift.1, isClosed: true,
                              rests: [RestSegment(start: shift.1, end: next, dailyRestConfirmed: next.map { _ in true },
                                                  kind: .daily)])
        }
        let model = DayLogModel(date: shifts[0].0)
        model.update { journal in
            journal.history = Array(periods.dropLast())
            journal.current = periods[periods.count - 1]
        }
        return model
    }

    /// The owner's week (HomeCountRowTests): weekly rest 20.10 → 21.10, a reduced rest ending 22.10, a regular one
    /// ending 23.10, a 14 h shift on 23.10 (reduction certain past 13 h) and a 13 h 38 shift on 24.10.
    private var ownerWeek: DayLogModel {
        model([(date(14, 6, 4), date(14, 20, 54), 300), (date(15, 6, 4), date(15, 18, 36), 300),
               (date(16, 5, 47), date(16, 18, 35), 300), (date(17, 5, 40), date(17, 8, 34), 128),
               (date(19, 5, 40), date(19, 11, 45), 300), (date(20, 5, 47), date(20, 12, 31), 300),
               (date(21, 12, 51), date(21, 23, 48), 570), (date(22, 8, 56), date(22, 17, 24), 300),
               (date(23, 6, 28), date(23, 20, 27), 600), (date(24, 5, 39), date(24, 19, 17), 601)])
    }

    // MARK: - Bed (reduced rest)

    /// The bed sits on the days the Home row of PR #13 gains a reduction: 21.10 → 0, 22.10 → 1, 23.10 → 2, 24.10 → 3.
    @Test func bedsFollowTheHomeRowOfEachDay() {
        let model = ownerWeek
        let now = date(25, 10)
        let beds = (14...25).filter { model.historyMarkers(on: day($0), now: now, calendar: calendar).contains(.reducedRest) }
        #expect(beds == [22, 23, 24])
        for value in 21...24 {
            let ids = model.reductionIDs(endOf: day(value), now: now, calendar: calendar)
            #expect(ids?.count == model.reducedRests(endOf: day(value), now: now, calendar: calendar))
        }
    }

    /// A reduced rest (10 h) after a 12 h shift: the bed sits on the day the rest ended, not on the shift day.
    @Test func aReducedRestDayGetsABed() {
        let model = model([(date(10, 6), date(10, 14), nil), (date(12, 8), date(12, 20), nil),
                           (date(13, 6), date(13, 12), nil)])
        let now = date(14, 12)
        #expect(model.historyMarkers(on: day(12), now: now, calendar: calendar) == [])
        #expect(model.historyMarkers(on: day(13), now: now, calendar: calendar) == [.reducedRest])
        #expect(model.historyMarkers(on: day(14), now: now, calendar: calendar) == [])
    }

    /// Without a completed weekly rest the count is unknown, so no bed is shown (as the gray row on Home).
    @Test func anUnknownCountShowsNoBeds() {
        let model = model([(date(12, 8), date(12, 20), nil), (date(13, 6), date(13, 12), nil)])
        #expect(model.historyMarkers(now: date(14, 12), calendar: calendar).values.allSatisfy { !$0.contains(.reducedRest) })
    }

    // MARK: - Wheel (extended driving)

    @Test func extendedDrivingIsOverNineHoursUpToTen() {
        #expect(!HistoryMarkers.isExtendedDriving(minutes: nil))
        #expect(!HistoryMarkers.isExtendedDriving(minutes: 540))
        #expect(HistoryMarkers.isExtendedDriving(minutes: 541))
        #expect(HistoryMarkers.isExtendedDriving(minutes: 600))
        #expect(!HistoryMarkers.isExtendedDriving(minutes: 601), "over 10 h is a violation (later task)")
    }

    @Test func anExtendedDrivingDayGetsAWheel() {
        let model = ownerWeek
        let now = date(25, 10)
        #expect(model.historyMarkers(on: day(21), now: now, calendar: calendar) == [.extendedDriving])
        #expect(model.historyMarkers(on: day(19), now: now, calendar: calendar) == [])
    }

    @Test func bothMarkersOnOneDay() {
        let model = ownerWeek
        #expect(model.historyMarkers(on: day(23), now: date(25, 10), calendar: calendar) == [.reducedRest, .extendedDriving])
    }

    /// A shift 22:00 → 08:00 with 9 h 30 driving belongs to its start date only (decision 4).
    @Test func aShiftAcrossMidnightStaysOnItsStartDate() {
        let model = model([(date(10, 6), date(10, 14), nil), (date(12, 22), date(13, 8), 570),
                           (date(14, 6), date(14, 12), nil)])
        let now = date(15, 12)
        #expect(model.historyMarkers(on: day(12), now: now, calendar: calendar) == [.extendedDriving])
        #expect(model.historyMarkers(on: day(13), now: now, calendar: calendar) == [])
        #expect(model.historyRecord(on: day(13), calendar: calendar) == nil)
        #expect(model.historyRecord(on: day(12), calendar: calendar)?.drivingMinutes == 570)
    }

    @Test func normalDaysHaveNoMarkers() {
        let markers = ownerWeek.historyMarkers(now: date(25, 10), calendar: calendar)
        for value in [14, 15, 16, 17, 18, 19, 20, 25] {
            #expect(markers[day(value)] == nil, "day \(value)")
        }
        #expect(markers.count == 4)
    }

    @Test func futureDaysHaveNoMarkers() {
        let model = ownerWeek
        #expect(model.historyMarkers(on: day(23), now: date(22, 12), calendar: calendar) == [])
    }

    /// Markers are derived on every read, so a history edit moves them (R-E01).
    @Test func markersFollowAHistoryEdit() {
        let model = ownerWeek
        let now = date(25, 10)
        model.setDriving(minutes: 300, onDay: day(21), calendar: calendar)
        #expect(model.historyMarkers(on: day(21), now: now, calendar: calendar) == [])
    }

    // MARK: - Day summary sheet

    /// The sheet shows the same values as Home's past-day cards for that day.
    @Test func theSheetMatchesHomeForThePastDay() {
        let model = ownerWeek
        let now = date(25, 10)
        let target = day(23)
        let summary = DaySummary(model: model, day: target, now: now, calendar: calendar)
        let record = model.dayRecord(on: target, calendar: calendar)
        #expect(!summary.isEmpty)
        #expect(summary.subtitle == "\(HomeTimeline.dateLabel(target, calendar: calendar)) 2026")
        #expect(summary.times.map(\.value) == [
            HomeTimeline.clockLabel(record!.start!, relativeTo: target, calendar: calendar),
            HomeTimeline.drivingLabel(minutes: record?.drivingMinutes),
            HomeTimeline.clockLabel(record!.end!, relativeTo: target, calendar: calendar),
        ])
        #expect(summary.times.map(\.value) == ["06:28", "10h00m", "20:27"])
        #expect(summary.workValue == "13:59")
        let rest = model.restTaken(after: record, now: now)
        #expect(summary.restValue == HomeTimeline.clockDuration(seconds: rest!.seconds))
        #expect(summary.restValue == "09:12")
        #expect(summary.restLimit == "Taken")
        #expect(summary.reducedRestsUsed == model.reducedRests(endOf: target, now: now, calendar: calendar))
        #expect(summary.reducedRestsUsed == 2)
    }

    /// An empty day shows "No records for this day." and browsing writes nothing.
    @Test func anEmptyDayHasNoRecordAndBrowsingCreatesNone() throws {
        let model = ownerWeek
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(model.state)
        let summary = DaySummary(model: model, day: day(18), now: date(25, 10), calendar: calendar)
        _ = model.historyMarkers(now: date(25, 10), calendar: calendar)
        #expect(summary.isEmpty)
        #expect(summary.times.map(\.value) == ["?", "?", "?"])
        #expect(try encoder.encode(model.state) == before)
    }

    /// Today's open shift is shown in the sheet with its running duration, as on Home.
    @Test func todaysOpenShiftShowsItsRunningDuration() {
        let model = DayLogModel(date: date(25, 6))
        model.setDayStart(date(25, 6))
        let summary = DaySummary(model: model, day: day(25), now: date(25, 8, 30), calendar: calendar)
        #expect(summary.workValue == "02:30")
        #expect(summary.restValue == "?")
    }

    @Test func spokenMarkerNames() {
        #expect(HistoryDayMarkers([.reducedRest, .extendedDriving]).spokenNames == ["reduced rest", "extended driving"])
        #expect(HistoryDayMarkers.extendedDriving.spokenNames == ["extended driving"])
    }
}
