import Foundation
import Testing
@testable import TachoBook

/// Start of day at 3 of 3 without a confirmed split: counts down to 11 h, warns from 9 h, orange at 11 h
/// (owner decision 01.11.2026). Every other case keeps 9 h with no warning. Europe/Berlin.
@MainActor
struct StartOfDayAtThreeOfThreeTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private let hour: TimeInterval = 3600

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// Shift 06:00–18:00 on 5.11, its daily rest running from 18:00.
    private var anchor: Date { date(5, 6) }
    private var restStart: Date { date(5, 18) }

    private func at(_ hours: Int, _ minutes: Int = 0) -> Date {
        restStart.addingTimeInterval(TimeInterval(hours) * hour + TimeInterval(minutes) * 60)
    }

    /// A weekly rest, `used` days of 12 h duty with a 10 h (reduced) rest, then the current shift and its rest.
    /// `used` nil leaves out the weekly rest, so the count is unknown (R-U01).
    private func model(used: Int?, pauses: [RestSegment] = [], kind: RestKind = .daily) -> DayLogModel {
        var history: [DutyPeriod] = []
        if let used {
            var next = anchor
            func prepend(duty: TimeInterval, gap: TimeInterval, kind: RestKind) {
                let start = next.addingTimeInterval(-gap)
                let end = start.addingTimeInterval(duty)
                history.insert(DutyPeriod(date: start, start: start, end: end, isClosed: true,
                                          rests: [RestSegment(start: end, end: next, dailyRestConfirmed: true, kind: kind)]),
                               at: 0)
                next = start
            }
            for _ in 0..<used { prepend(duty: 12 * hour, gap: 22 * hour, kind: .daily) }
            prepend(duty: 8 * hour, gap: 54 * hour, kind: .weekly)
        }
        let model = DayLogModel(date: anchor)
        model.update { journal in
            journal.history = history
            journal.current = DutyPeriod(date: anchor, start: anchor, end: restStart, isClosed: true,
                                         rests: pauses + [RestSegment(start: restStart, kind: kind)])
        }
        return model
    }

    // MARK: - 3 of 3 without a split

    @Test func threeOfThreeWaitsForElevenHoursAndWarnsFromNine() {
        let model = model(used: 3)
        #expect(model.reducedRestsUsed == 3)
        #expect(model.dutyLimitAvailability == .thirteenHoursOnly)

        // 8:59 — dimmed, disabled, counting down to 11 h.
        let before = model.startOfDayAvailability(now: at(8, 59))
        #expect(before == .waiting(countdown: "02:01"))
        #expect(!before.isEnabled)

        // 9:00 and 10:59 — dimmed but enabled, still counting down to 11 h, warning on tap.
        #expect(model.startOfDayAvailability(now: at(9)) == .earlyStart(countdown: "02:00", fullRestEnd: at(11)))
        let late = model.startOfDayAvailability(now: at(10, 59))
        #expect(late == .earlyStart(countdown: "00:01", fullRestEnd: at(11)))
        #expect(late.isEnabled)

        // 11:00 — orange, no countdown, no warning.
        let full = model.startOfDayAvailability(now: at(11))
        #expect(full == .available)
        #expect(full.countdown == nil)
    }

    /// The warning's {time}: rest start + 11 h, as the Home clock labels show it.
    @Test func warningTimeIsRestStartPlusElevenHours() {
        guard case .earlyStart(_, let fullRestEnd) = model(used: 3).startOfDayAvailability(now: at(9, 30)) else {
            Issue.record("expected the early-start state")
            return
        }
        #expect(HomeTimeline.clockLabel(fullRestEnd, relativeTo: at(9, 30), calendar: calendar) == "05:00")
    }

    /// The sheet keeps its 9 h check, so a start between 9 h and 11 h is recorded as usual.
    @Test func anEarlyStartIsStillRecorded() {
        let model = model(used: 3)
        let now = at(9, 30)
        #expect(!model.canStartShift(at: at(8, 59), now: now))
        #expect(model.canStartShift(at: now, now: now))
        model.startShift(at: now, now: now)
        #expect(model.isShiftOpen)
        #expect(model.dayStart == now)
    }

    // MARK: - Unchanged cases: 9 h, no warning

    @Test(arguments: [0, 1, 2])
    func belowThreeKeepsNineHours(used: Int) {
        expectCurrentBehaviour(model(used: used))
    }

    @Test func aConfirmedSplitFirstPauseKeepsNineHours() {
        let pause = RestSegment(start: date(5, 9), end: date(5, 12), dailyRestConfirmed: true, kind: .daily)
        let model = model(used: 3, pauses: [pause])
        #expect(model.dutyLimitAvailability == .fifteenHours)
        expectCurrentBehaviour(model)
    }

    @Test func anUnknownCountKeepsNineHours() {
        let model = model(used: nil)
        #expect(model.reducedRestsUsed == nil)
        #expect(model.dutyLimitAvailability == .unknown)
        expectCurrentBehaviour(model)
    }

    @Test func aWeeklyRestKeepsFortyFiveHours() {
        let model = model(used: 3, kind: .weekly)
        #expect(model.startOfDayAvailability(now: at(44, 59)) == .waiting(countdown: "00:01"))
        #expect(model.startOfDayAvailability(now: at(45)) == .available)
    }

    @Test func noRestIsAvailable() {
        #expect(HomeTimeline.startOfDayAvailability(restStart: nil, kind: .daily, limits: .thirteenHoursOnly,
                                                    now: date(5, 6)) == .available)
    }

    /// Orange at 9 h, never a warning, and the same countdown as before this change.
    private func expectCurrentBehaviour(_ model: DayLogModel) {
        let before = model.startOfDayAvailability(now: at(8, 59))
        #expect(before == .waiting(countdown: "00:01"))
        #expect(before.countdown == HomeTimeline.availabilityCountdown(restStart: restStart, kind: .daily, now: at(8, 59)))
        for now in [at(9), at(10, 59), at(11)] {
            #expect(model.startOfDayAvailability(now: now) == .available)
        }
    }
}
