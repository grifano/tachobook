//
//  DayHistory.swift
//  TachoBook
//

import Foundation

/// Pure rules for browsing and correcting earlier days (MVP-07).
/// A day is the calendar date of the shift start; a shift across midnight stays on its start date.
public enum DayHistory {
    /// How many days before today the driver can swipe back. Deeper history belongs to a
    /// calendar entry point (separate task).
    public static let maxDaysBack = 3

    /// Midnight of the day `daysBack` before `now`.
    public static func day(daysBack: Int, from now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -max(0, daysBack), to: today) ?? today
    }

    /// How many days before today `date` falls, if the swipe can reach it (today … `maxDaysBack`).
    public static func daysBack(of date: Date, from now: Date, calendar: Calendar = .current) -> Int? {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day
        guard let days, (0...maxDaysBack).contains(days) else { return nil }
        return days
    }

    /// The day (midnight) a record belongs to: its start date, else the date it was created on.
    public static func recordDay(_ period: DutyPeriod, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: period.start ?? period.date)
    }

    /// The span a record occupies, used for overlap checks. A record with only one timestamp
    /// is a point; the open active shift runs up to `now`.
    static func interval(of period: DutyPeriod, isActive: Bool, now: Date) -> (start: Date, end: Date)? {
        switch (period.start, period.end) {
        case let (start?, end?): return (start, max(start, end))
        case let (start?, nil): return (start, isActive ? max(start, now) : start)
        case let (nil, end?): return (end, end)
        case (nil, nil): return nil
        }
    }

    /// Touching spans do not overlap: a shift may start at the instant the previous one ended.
    static func overlaps(_ a: (start: Date, end: Date), _ b: (start: Date, end: Date)) -> Bool {
        a.start < b.end && b.start < a.end
    }

    /// Time of day taken from `time`, date taken from `day`; used for the sheets' default value.
    public static func combine(day: Date, timeOf time: Date, calendar: Calendar = .current) -> Date {
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: 0, of: day) ?? day
    }

    /// The first instant of `day` up to the last one.
    public static func range(of day: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let start = calendar.startOfDay(for: day)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return start...next.addingTimeInterval(-60)
    }
}

/// Why a time cannot be confirmed in a time sheet (F4). `.other` is a disabled case without approved copy.
public enum TimeEntryIssue: Equatable {
    case future
    case endBeforeStart(start: Date)
    /// `to` nil means the current (open) shift.
    case overlap(from: Date, to: Date?)
    case outsideDay(Date)
    /// A printout time before the violation began (decision 19). Copy approved by Serhii, 07.11.2026.
    case printoutTooEarly(Date, ViolationKind)
    case other

    /// Interim copy, plain and friendly; dates follow the device locale.
    public func message(calendar: Calendar = .current) -> String? {
        switch self {
        case .future:
            return "This time hasn't happened yet."
        case .endBeforeStart(let start):
            return "Day closed can\u{2019}t be before Day started (\(HomeTimeline.dayAndTime(start, calendar: calendar)))."
        case .overlap(let from, let to):
            let begin = HomeTimeline.dayAndTime(from, calendar: calendar)
            guard let to else { return "This overlaps your current shift from \(begin)." }
            return "This overlaps your shift from \(begin) to \(HomeTimeline.dayAndTime(to, calendar: calendar))."
        case .outsideDay(let day):
            return "Pick a time on \(HomeTimeline.weekdayAndDay(day, calendar: calendar))."
        case .printoutTooEarly(let began, let kind):
            let moment = HomeTimeline.dayAndTime(began, calendar: calendar)
            return kind == .dutyLimit
                ? "Pick a time after your limit passed (\(moment))."
                : "Pick a time after your rest started (\(moment))."
        case .other:
            return nil
        }
    }
}

/// A past day on Home without a shift record (Figma "Past Day Covered - 02", 838:33650): the No activities widget.
public struct NoActivitiesDay {
    /// The latest shift that started before the day; nil when there is none (the widget shows only its top part).
    public var lastShift: DutyPeriod?

    /// Where "Tap to see this day" leads.
    public enum Target: Equatable {
        /// The day is within the Home swipe: show it there.
        case home(daysBack: Int)
        /// Older: the History tab with the Day summary of that date.
        case history(day: Date)
    }

    /// The day the last shift belongs to (its start date), on Home when the swipe reaches it, else in History.
    public func target(now: Date, calendar: Calendar = .current) -> Target? {
        guard let lastShift else { return nil }
        let day = DayHistory.recordDay(lastShift, calendar: calendar)
        if let daysBack = DayHistory.daysBack(of: day, from: now, calendar: calendar) { return .home(daysBack: daysBack) }
        return .history(day: day)
    }
}

/// Rest taken after a shift: next shift start minus this shift's end, or the time up to
/// now while it is still running. Never classified as daily or weekly.
public struct RestTaken: Equatable {
    public var start: Date
    /// nil while the rest is still running.
    public var end: Date?
    public var seconds: Int
}

extension Array where Element == DutyPeriod {
    mutating func sortChronologically() {
        // Stable: equal keys keep their order.
        self = enumerated()
            .sorted { ($0.element.start ?? $0.element.date, $0.offset) < ($1.element.start ?? $1.element.date, $1.offset) }
            .map(\.element)
    }
}

extension DayLogModel {
    /// Every stored period, archived first, with whether it is the open active shift.
    private var allPeriods: [(period: DutyPeriod, isActive: Bool)] {
        state.history.map { ($0, false) } + [(state.current, isShiftOpen)]
    }

    /// The earliest other record or the active shift that `start...end` collides with.
    /// `to` is nil for the open shift.
    func overlapBlocker(start: Date, end: Date, excluding id: UUID?, now: Date) -> (from: Date, to: Date?)? {
        let span = (start: start, end: max(start, end))
        let hits = allPeriods.compactMap { entry -> (from: Date, to: Date?)? in
            guard entry.period.id != id,
                  let other = DayHistory.interval(of: entry.period, isActive: entry.isActive, now: now),
                  DayHistory.overlaps(span, other) else { return nil }
            return (other.start, entry.isActive ? nil : other.end)
        }
        return hits.min { $0.from < $1.from }
    }

    /// Whether `start...end` collides with any other record or the active shift.
    func overlapsOtherRecords(start: Date, end: Date, excluding id: UUID?, now: Date) -> Bool {
        overlapBlocker(start: start, end: end, excluding: id, now: now) != nil
    }

    /// The record shown for `day`. The open active shift belongs to Home today and is never a
    /// past-day record; a closed shift in its rest is (it is the latest closed shift).
    public func dayRecord(on day: Date, calendar: Calendar = .current) -> DutyPeriod? {
        let target = calendar.startOfDay(for: day)
        var candidates = state.history
        if state.current.start != nil, !isShiftOpen { candidates.append(state.current) }
        candidates.sortChronologically()
        return candidates.last { DayHistory.recordDay($0, calendar: calendar) == target }
    }

    /// Rest taken after `record`. nil when the shift has no Day closed yet.
    public func restTaken(after record: DutyPeriod?, now: Date) -> RestTaken? {
        guard let record, let end = record.end else { return nil }
        let next = allPeriods
            .map(\.period)
            .filter { $0.id != record.id && ($0.start.map { $0 >= end } ?? false) }
            .min { $0.start! < $1.start! }
        if let nextStart = next?.start {
            return RestTaken(start: end, end: nextStart, seconds: max(0, Int(nextStart.timeIntervalSince(end))))
        }
        return RestTaken(start: end, end: nil, seconds: max(0, Int(now.timeIntervalSince(end))))
    }

    // MARK: - Entering and editing a past day (R-E01)

    private func isCurrent(_ record: DutyPeriod?) -> Bool { record?.id == state.current.id }

    public func canSetStart(_ date: Date, onDay day: Date, now: Date, calendar: Calendar = .current) -> Bool {
        checkSetStart(date, onDay: day, now: now, calendar: calendar) == nil
    }

    public func checkSetStart(_ date: Date, onDay day: Date, now: Date, calendar: Calendar = .current) -> TimeEntryIssue? {
        guard storageError == nil else { return .other }
        if date > now { return .future }
        guard calendar.isDate(date, inSameDayAs: day) else { return .outsideDay(day) }
        let record = dayRecord(on: day, calendar: calendar)
        if isCurrent(record) { return checkEditDayStart(date, now: now) }
        if let end = record?.end, date > end { return .endBeforeStart(start: date) }
        if let blocker = overlapBlocker(start: date, end: record?.end ?? date, excluding: record?.id, now: now) {
            return .overlap(from: blocker.from, to: blocker.to)
        }
        return nil
    }

    /// `place` replaces the start country; nil keeps the stored one.
    public func setStart(_ date: Date, onDay day: Date, now: Date, place: ShiftPlace? = nil,
                         calendar: Calendar = .current) {
        guard canSetStart(date, onDay: day, now: now, calendar: calendar), place?.isComplete ?? true else { return }
        let record = dayRecord(on: day, calendar: calendar)
        if isCurrent(record) { return editDayStart(date, now: now, place: place) }
        update { journal in
            if let id = record?.id, let index = journal.history.firstIndex(where: { $0.id == id }) {
                journal.history[index].start = date
                journal.history[index].date = date
                if let place { journal.history[index].startPlace = place }
            } else {
                journal.history.append(DutyPeriod(date: date, start: date, startPlace: place))
            }
            journal.history.sortChronologically()
        }
    }

    public func canSetEnd(_ date: Date, onDay day: Date, now: Date, calendar: Calendar = .current) -> Bool {
        checkSetEnd(date, onDay: day, now: now, calendar: calendar) == nil
    }

    public func checkSetEnd(_ date: Date, onDay day: Date, now: Date, calendar: Calendar = .current) -> TimeEntryIssue? {
        guard storageError == nil else { return .other }
        if date > now { return .future }
        let record = dayRecord(on: day, calendar: calendar)
        if let start = record?.start {
            if date < start { return .endBeforeStart(start: start) }
        } else if date < calendar.startOfDay(for: day) {
            return .outsideDay(day)
        }
        if isCurrent(record) { return checkEditDayEnd(date, now: now) }
        if let blocker = overlapBlocker(start: record?.start ?? date, end: date, excluding: record?.id, now: now) {
            return .overlap(from: blocker.from, to: blocker.to)
        }
        return nil
    }

    /// `place` replaces the close country; nil keeps the stored one.
    public func setEnd(_ date: Date, onDay day: Date, now: Date, place: ShiftPlace? = nil,
                       calendar: Calendar = .current) {
        guard canSetEnd(date, onDay: day, now: now, calendar: calendar), place?.isComplete ?? true else { return }
        let record = dayRecord(on: day, calendar: calendar)
        if isCurrent(record) { return editDayEnd(date, now: now, place: place) }
        update { journal in
            if let id = record?.id, let index = journal.history.firstIndex(where: { $0.id == id }) {
                // The final rest starts at Day closed and moves with it; left behind, a later close would turn it into
                // a pause inside the shift (a split for the counter).
                if let oldEnd = journal.history[index].end, let last = journal.history[index].rests.indices.last,
                   journal.history[index].rests[last].start == oldEnd {
                    journal.history[index].rests[last].start = date
                }
                journal.history[index].end = date
                journal.history[index].isClosed = true
                if let place { journal.history[index].endPlace = place }
            } else {
                journal.history.append(DutyPeriod(date: calendar.startOfDay(for: day), end: date, isClosed: true,
                                                  endPlace: place))
            }
            journal.history.sortChronologically()
        }
    }

    public func canSetDriving(minutes: Int) -> Bool {
        storageError == nil && minutes >= 0
    }

    public func setDriving(minutes: Int, onDay day: Date, calendar: Calendar = .current) {
        guard canSetDriving(minutes: minutes) else { return }
        let record = dayRecord(on: day, calendar: calendar)
        if isCurrent(record) { return setDrivingMinutes(minutes) }
        update { journal in
            if let id = record?.id, let index = journal.history.firstIndex(where: { $0.id == id }) {
                journal.history[index].drivingMinutes = minutes
            } else {
                journal.history.append(DutyPeriod(date: calendar.startOfDay(for: day), drivingMinutes: minutes))
            }
            journal.history.sortChronologically()
        }
    }

    // MARK: - Past day without a shift (No activities widget)

    /// The No activities widget for a past `day` that has no shift record; nil for today, the future and days
    /// with a record.
    public func noActivitiesDay(onDay day: Date, now: Date, calendar: Calendar = .current) -> NoActivitiesDay? {
        let target = calendar.startOfDay(for: day)
        guard target < calendar.startOfDay(for: now), dayRecord(on: target, calendar: calendar) == nil,
              // The open shift is not a past-day record, but a shift started that day is still an activity.
              !(isShiftOpen && state.current.start.map { calendar.isDate($0, inSameDayAs: target) } == true)
        else { return nil }
        return NoActivitiesDay(lastShift: lastShift(before: target, calendar: calendar))
    }

    /// The latest record that started before `day`; a shift across midnight into `day` counts.
    public func lastShift(before day: Date, calendar: Calendar = .current) -> DutyPeriod? {
        let target = calendar.startOfDay(for: day)
        var candidates = allPeriods.map(\.period).filter { $0.start != nil || $0.end != nil }
        candidates.sortChronologically()
        return candidates.last { DayHistory.recordDay($0, calendar: calendar) < target }
    }
}
