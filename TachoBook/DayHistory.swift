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

    /// Whether `start...end` collides with any other record or the active shift.
    func overlapsOtherRecords(start: Date, end: Date, excluding id: UUID?, now: Date) -> Bool {
        let span = (start: start, end: max(start, end))
        return allPeriods.contains { entry in
            guard entry.period.id != id,
                  let other = DayHistory.interval(of: entry.period, isActive: entry.isActive, now: now) else { return false }
            return DayHistory.overlaps(span, other)
        }
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
        guard storageError == nil, date <= now, calendar.isDate(date, inSameDayAs: day) else { return false }
        let record = dayRecord(on: day, calendar: calendar)
        if isCurrent(record) { return canEditDayStart(date, now: now) }
        if let end = record?.end, date > end { return false }
        return !overlapsOtherRecords(start: date, end: record?.end ?? date, excluding: record?.id, now: now)
    }

    public func setStart(_ date: Date, onDay day: Date, now: Date, calendar: Calendar = .current) {
        guard canSetStart(date, onDay: day, now: now, calendar: calendar) else { return }
        let record = dayRecord(on: day, calendar: calendar)
        if isCurrent(record) { return editDayStart(date, now: now) }
        update { journal in
            if let id = record?.id, let index = journal.history.firstIndex(where: { $0.id == id }) {
                journal.history[index].start = date
                journal.history[index].date = date
            } else {
                journal.history.append(DutyPeriod(date: date, start: date))
            }
            journal.history.sortChronologically()
        }
    }

    public func canSetEnd(_ date: Date, onDay day: Date, now: Date, calendar: Calendar = .current) -> Bool {
        guard storageError == nil, date <= now else { return false }
        let record = dayRecord(on: day, calendar: calendar)
        let floor = record?.start ?? calendar.startOfDay(for: day)
        guard date >= floor else { return false }
        if isCurrent(record) { return canEditDayEnd(date, now: now) }
        return !overlapsOtherRecords(start: record?.start ?? date, end: date, excluding: record?.id, now: now)
    }

    public func setEnd(_ date: Date, onDay day: Date, now: Date, calendar: Calendar = .current) {
        guard canSetEnd(date, onDay: day, now: now, calendar: calendar) else { return }
        let record = dayRecord(on: day, calendar: calendar)
        if isCurrent(record) { return editDayEnd(date, now: now) }
        update { journal in
            if let id = record?.id, let index = journal.history.firstIndex(where: { $0.id == id }) {
                journal.history[index].end = date
                journal.history[index].isClosed = true
            } else {
                journal.history.append(DutyPeriod(date: calendar.startOfDay(for: day), end: date, isClosed: true))
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
}
