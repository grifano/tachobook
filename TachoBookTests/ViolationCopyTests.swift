import Foundation
import Testing
@testable import TachoBook

/// The texts of Flow 3, Flow 4 and the History Day summary, and the History marker (decision 20), in Europe/Berlin.
@MainActor
struct ViolationCopyTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func violation(_ kind: ViolationKind, limit: Int = 13) -> Violation {
        let start = date(19, 5, 40)
        return Violation(key: ViolationKey(periodID: UUID(), kind: kind), day: date(19, 0),
                         began: kind == .dutyLimit ? HomeTimeline.adding(hours: limit, to: start) : date(19, 21),
                         limitHours: kind == .dutyLimit ? limit : 9, dutyStart: start,
                         dutySeconds: limit * 3600 + 30 * 60, restSeconds: 8 * 3600 + 15 * 60, isOngoing: false)
    }

    @Test func sheetTexts() {
        let duty = violation(.dutyLimit)
        #expect(ViolationCopy.title(duty) == "Shift limit passed")
        #expect(ViolationCopy.homeSheetTitle(duty) == "13h limit passed")
        #expect(ViolationCopy.homeSheetSubtitle(duty, now: date(19, 19, 10), calendar: calendar) == "Over by 0:30 since 18:40")
        #expect(ViolationCopy.sheetSubtitle(duty, calendar: calendar) == "Mon 19 Oct · over by 0:30 since 18:40")
        #expect(ViolationCopy.redLine(duty) == "You\u{2019}ve passed your 13-hour shift limit.")
        #expect(ViolationCopy.redLine(violation(.dutyLimit, limit: 15)) == "You\u{2019}ve passed your 15-hour shift limit.")

        let rest = violation(.shortRest)
        #expect(ViolationCopy.title(rest) == "Daily rest under 9h")
        #expect(ViolationCopy.sheetSubtitle(rest, calendar: calendar) == "Mon 19 Oct · rest 8:15 in 24 h")
        #expect(ViolationCopy.redLine(rest) == "Your daily rest was shorter than 9 hours.")
    }

    @Test func rowAndPrintoutTexts() {
        let duty = violation(.dutyLimit)
        let missing = PrintoutCarry.status(violationDay: duty.day, printedAt: nil, now: date(20, 9), calendar: calendar)
        #expect(ViolationCopy.rowSubtitle(duty, status: missing, calendar: calendar) == "No printout marked yet · ?")
        let printed = date(19, 21, 15)
        let done = PrintoutCarry.status(violationDay: duty.day, printedAt: printed, now: date(2, 9, month: 11), calendar: calendar)
        #expect(ViolationCopy.rowSubtitle(duty, status: done, calendar: calendar) == "Carry until 14 Dec · 42 days left")
        #expect(ViolationCopy.printoutLine(printedAt: printed, status: done, calendar: calendar)
                == "Printout done on 19 Oct. Carry it with you until 14 Dec · 42 days left.")
        let last = PrintoutCarry.status(violationDay: duty.day, printedAt: printed, now: date(13, 9, month: 12), calendar: calendar)
        #expect(ViolationCopy.rowSubtitle(duty, status: last, calendar: calendar) == "Carry until 14 Dec · 1 day left")
        let older = PrintoutCarry.status(violationDay: duty.day, printedAt: printed, now: date(15, 9, month: 12), calendar: calendar)
        #expect(ViolationCopy.rowSubtitle(duty, status: older, calendar: calendar) == "19 Oct · no need to carry it")
        #expect(ViolationCopy.printoutLine(printedAt: printed, status: older, calendar: calendar)
                == "Printout done on 19 Oct · no need to carry it.")
        let olderMissing = PrintoutCarry.status(violationDay: duty.day, printedAt: nil, now: date(15, 9, month: 12), calendar: calendar)
        #expect(ViolationCopy.rowSubtitle(duty, status: olderMissing, calendar: calendar) == "No printout marked · ?")
    }

    @Test func noteIsTheApprovedTemplate() {
        let lines = ViolationCopy.note.split(separator: "\n")
        #expect(lines.count == 4)
        #expect(lines.first == "Art. 12 EC 561/2006")
        #expect(lines.last == "Name, surname, signature")
        #expect(ViolationCopy.violationCount(0) == "No violations")
        #expect(ViolationCopy.violationCount(1) == "1 violation")
        #expect(ViolationCopy.violationCount(2) == "2 violations")
    }

    @Test func historyMarksTheShiftDayAndFollowsEdits() {
        // A 16 h shift on 12 Oct (no weekly rest in the records: only past 15 h counts), then a regular rest.
        let shift = DutyPeriod(date: date(12, 6), start: date(12, 6), end: date(12, 22), isClosed: true)
        let next = DutyPeriod(date: date(13, 14), start: date(13, 14))
        let model = DayLogModel(journal: ShiftJournal(current: next, history: [shift]))
        let now = date(13, 15)
        #expect(model.historyMarkers(on: date(12, 0), now: now, calendar: calendar).contains(.violation))
        #expect(!model.historyMarkers(on: date(13, 0), now: now, calendar: calendar).contains(.violation))
        #expect(model.historyMarkers(now: now, calendar: calendar)[date(12, 0)]?.contains(.violation) == true)
        #expect(HistoryDayMarkers.violation.spokenNames == ["rule broken"])
        // Correcting the close to 20:00 (14 h) removes it (R-E01).
        model.setEnd(date(12, 20), onDay: date(12, 0), now: now, calendar: calendar)
        #expect(!model.historyMarkers(on: date(12, 0), now: now, calendar: calendar).contains(.violation))
    }
}
