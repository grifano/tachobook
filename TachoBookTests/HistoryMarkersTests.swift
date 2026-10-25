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

    /// The owner's week (HomeCountRowTests): weekly rest 20.10 → 21.10, a reduced rest after the 21.10 shift
    /// (9 h 08), a regular one after 22.10, a reduced one after the 14 h shift of 23.10 (9 h 12) and a 13 h 38
    /// shift on 24.10 whose rest is still running (reduction certain past 13 h). Extended driving 22.10 and 23.10.
    private var ownerWeek: DayLogModel {
        model([(date(14, 6, 4), date(14, 20, 54), 300), (date(15, 6, 4), date(15, 18, 36), 300),
               (date(16, 5, 47), date(16, 18, 35), 300), (date(17, 5, 40), date(17, 8, 34), 128),
               (date(19, 5, 40), date(19, 11, 45), 300), (date(20, 5, 47), date(20, 12, 31), 300),
               (date(21, 12, 51), date(21, 23, 48), 300), (date(22, 8, 56), date(22, 17, 24), 570),
               (date(23, 6, 28), date(23, 20, 27), 600), (date(24, 5, 39), date(24, 19, 17), 601)])
    }

    // MARK: - Bed (reduced rest)

    /// The bed sits on the day of the shift whose rest is reduced (Serhii, 25.10.2026): 21.10, not 22.10 when
    /// that rest ended. The sheet counts every reduction up to the day, its own shift's rest included.
    @Test func bedsSitOnTheShiftDayAndTheSheetCountsThem() {
        let model = ownerWeek
        let now = date(25, 10)
        let beds = (14...25).filter { model.historyMarkers(on: day($0), now: now, calendar: calendar).contains(.reducedRest) }
        #expect(beds == [21, 23, 24])
        let counts = (20...25).map { model.historyReducedRests(onDay: day($0), now: now, calendar: calendar) }
        #expect(counts == [0, 1, 1, 2, 3, 3])
    }

    /// A reduced rest (10 h) after a 12 h shift: the bed sits on the shift day, not on the day the rest ended.
    @Test func aReducedRestDayGetsABed() {
        let model = model([(date(10, 6), date(10, 14), nil), (date(12, 8), date(12, 20), nil),
                           (date(13, 6), date(13, 12), nil)])
        let now = date(14, 12)
        #expect(model.historyMarkers(on: day(12), now: now, calendar: calendar) == [.reducedRest])
        #expect(model.historyMarkers(on: day(13), now: now, calendar: calendar) == [])
        #expect(model.historyMarkers(on: day(14), now: now, calendar: calendar) == [])
        #expect(model.historyReducedRests(onDay: day(12), now: now, calendar: calendar) == 1)
    }

    /// A 14 h shift followed by a weekly rest is no reduction, and the next week starts from zero.
    @Test func aLongShiftBeforeAWeeklyRestIsNoReduction() {
        let model = model([(date(10, 6), date(10, 14), nil), (date(12, 6), date(12, 20), nil),
                           (date(14, 8), date(14, 16), nil)])
        let now = date(15, 12)
        #expect(model.historyMarkers(on: day(12), now: now, calendar: calendar) == [])
        #expect(model.historyReducedRests(onDay: day(12), now: now, calendar: calendar) == 0)
        #expect(model.historyReducedRests(onDay: day(14), now: now, calendar: calendar) == 0)
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
        #expect(model.historyMarkers(on: day(22), now: now, calendar: calendar) == [.extendedDriving])
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
        model.setDriving(minutes: 300, onDay: day(22), calendar: calendar)
        #expect(model.historyMarkers(on: day(22), now: now, calendar: calendar) == [])
    }

    // MARK: - Day summary sheet

    /// The sheet shows the same times and gauges as Home's past-day cards; its row counts the day's own rest.
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
        #expect(summary.restLimit == "9h", "the rest after the 23.10 shift lasted 9 h 12")
        #expect(summary.workLimit == "15h", "the 23.10 shift lasted 13 h 59")
        #expect(summary.reducedRestsUsed == 2)
        let monday = DaySummary(model: model, day: day(21), now: now, calendar: calendar)
        #expect(monday.reducedRestsUsed == 1, "the reduced rest after the 21.10 shift counts on 21.10")
    }

    /// Past-day labels by length (Serhii, 25.10.2026): duty up to 13 h → 13h, beyond → 15h; rest under 11 h → 9h,
    /// 11–24 h → 11h, 24–45 h → 24h, 45 h or more → 45h.
    @Test func pastDayGaugeLabelsFollowTheLength() {
        let hour = 3600
        #expect(HomeTimeline.pastDutyLimitHours(seconds: nil) == 15)
        #expect(HomeTimeline.pastDutyLimitHours(seconds: 8 * hour) == 13)
        #expect(HomeTimeline.pastDutyLimitHours(seconds: 13 * hour) == 13)
        #expect(HomeTimeline.pastDutyLimitHours(seconds: 13 * hour + 60) == 15)
        #expect(HomeTimeline.restNormHours(seconds: 9 * hour + 11 * 60) == 9)
        #expect(HomeTimeline.restNormHours(seconds: 11 * hour - 60) == 9)
        #expect(HomeTimeline.restNormHours(seconds: 11 * hour) == 11)
        #expect(HomeTimeline.restNormHours(seconds: 12 * hour) == 11)
        #expect(HomeTimeline.restNormHours(seconds: 24 * hour) == 24)
        #expect(HomeTimeline.restNormHours(seconds: 45 * hour - 60) == 24)
        #expect(HomeTimeline.restNormHours(seconds: 45 * hour) == 45)
        #expect(HomeTimeline.restTakenLabel(nil) == "Taken")
        #expect(HomeTimeline.restTakenLabel(RestTaken(start: date(1, 8), end: nil, seconds: 3600)) == "So far")
    }

    /// The Work ring of the sheet: 13h for the 8 h 28 shift of 22.10, 15h for the 13 h 59 shift of 23.10,
    /// and 15h while today's shift is still open.
    @Test func theWorkRingNamesThirteenOrFifteenHours() {
        let model = ownerWeek
        let now = date(25, 10)
        #expect(DaySummary(model: model, day: day(22), now: now, calendar: calendar).workLimit == "13h")
        #expect(DaySummary(model: model, day: day(23), now: now, calendar: calendar).workLimit == "15h")
        let open = DayLogModel(date: date(25, 6))
        open.setDayStart(date(25, 6))
        #expect(DaySummary(model: open, day: day(25), now: date(25, 8), calendar: calendar).workLimit == "15h")
    }

    /// The Rest ring names the norm the rest met: 9 h reduced, 11 h regular, 24 h / 45 h weekly, "So far" while it runs.
    @Test func theRestRingNamesTheNormTheRestMet() {
        let model = ownerWeek
        let now = date(25, 10)
        func norm(_ value: Int) -> String { DaySummary(model: model, day: day(value), now: now, calendar: calendar).restLimit }
        #expect(norm(21) == "9h")
        #expect(norm(22) == "11h", "13 h 03 after the 22.10 shift")
        #expect(norm(20) == "24h", "24 h 20 from 20.10 to 21.10")
        #expect(norm(17) == "45h", "17.10 08:34 to 19.10 05:40")
        #expect(norm(24) == "So far")
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
