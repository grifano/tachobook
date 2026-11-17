import Foundation
import Testing
@testable import TachoBook

/// Add past violation (owner decisions 17.11.2026): a past violation is entered as its shift through the Add past
/// shift flow, its printout made earlier counts the 56 days from the printout day, and the gray "Older than 56 days"
/// group shows its newest five rows until Show all.
@MainActor
struct PastViolationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// 16.11.2026 18:00.
    private var now: Date { date(16, 18) }

    // MARK: - A past violation and its earlier printout

    @Test func aPastShiftsViolationTakesAnEarlierPrintoutAndCountsFromItsDay() throws {
        let model = DayLogModel(date: now)
        var entry = PastShiftDraft(now: now, calendar: calendar)
        entry.start = date(10, 5)
        entry.end = date(10, 21)
        entry.startPlace = ShiftPlace(country: "PL")
        entry.endPlace = ShiftPlace(country: "PL")
        // 16 h with the count unknown: only past 15 h is certain (R-U01), so the limit was passed at 20:00.
        #expect(model.savePastShift(entry, drivingMinutes: 480, now: now, calendar: calendar))
        let violation = try #require(model.pastShiftViolation(id: entry.id, now: now, calendar: calendar))
        #expect(violation.began == date(10, 20))

        // The printout can be neither before the violation nor in the future (decision 19).
        #expect(model.checkPrintout(date(10, 19, 59), for: violation, now: now) != nil)
        #expect(model.checkPrintout(now.addingTimeInterval(60), for: violation, now: now) != nil)
        model.markPrintout(date(10, 19), for: violation, now: now)
        #expect(model.printout(for: violation.key) == nil, "a refused time is not saved")

        // Printed that evening: carried until 10.11 + 56 days, 50 days left on 16.11.
        model.markPrintout(date(10, 21, 30), for: violation, now: now)
        let status = model.carryStatus(of: violation, now: now, calendar: calendar)
        #expect(status.carryUntil == calendar.date(from: DateComponents(year: 2027, month: 1, day: 5)))
        #expect(status.daysLeft == 50)
        #expect(!status.isOlder)
    }

    // MARK: - The gray group's cap

    private func rows(_ count: Int, older: Bool) -> [ViolationsCard.Row] {
        (0..<count).map { index in
            ViolationsCard.Row(key: ViolationKey(periodID: UUID(), kind: .shortRest), title: "Row \(index)",
                               subtitle: "", isPrintoutDone: false, isOlder: older)
        }
    }

    @Test func theGrayGroupShowsItsNewestFiveUntilShowAll() {
        let older = rows(7, older: true)
        let shown = ViolationsCard.shownOlder(older, showsAll: false)
        #expect(shown.map(\.title) == ["Row 0", "Row 1", "Row 2", "Row 3", "Row 4"], "the list is newest first")
        #expect(ViolationsCard.shownOlder(older, showsAll: true) == older)
    }

    @Test func fiveOrFewerOlderRowsAreAllShown() {
        for count in [0, 3, 5] {
            let older = rows(count, older: true)
            #expect(ViolationsCard.shownOlder(older, showsAll: false) == older)
        }
    }

    @Test func theUITestSeedAddsOlderViolations() {
        let model = DayLogModel(date: now)
        model.seedViolationsIfEmpty(now: now, extraOlder: 6, calendar: calendar)
        let violations = model.violations(now: now, calendar: calendar)
        let older = violations.filter { model.carryStatus(of: $0, now: now, calendar: calendar).isOlder }
        #expect(older.count == 7)
        #expect(older.allSatisfy { $0.kind == .shortRest })
        #expect(violations.count - older.count == 2, "the recent shift limit and short rest stay as they were")
    }
}
