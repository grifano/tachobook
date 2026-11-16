//
//  PastShift.swift
//  TachoBook
//

import Foundation

/// A shift for an earlier day entered by hand ("Add past shift", owner decision 5, 16.11.2026). It is filled step by
/// step in the normal shift sheets (start → close → driving) and saved only after the last step, so a Cancel on any
/// step leaves the records untouched.
public struct PastShiftDraft: Equatable, Sendable {
    /// The id the saved record gets, so a preview can name it before it exists.
    public let id: UUID
    public var start: Date
    public var startPlace: ShiftPlace?
    public var end: Date?
    public var endPlace: ShiftPlace?
    /// Records the driver agreed to replace (the replace alert). Nothing else is ever overwritten.
    public var replacing: Set<UUID> = []

    /// `day` preselects the shift start on that day (from Home, next Task); nil starts at `now` (History).
    /// The time of day is taken from `now`, never later than `now`.
    public init(day: Date? = nil, now: Date, id: UUID = UUID(), calendar: Calendar = .current) {
        self.id = id
        start = day.map { min(DayHistory.combine(day: $0, timeOf: now, calendar: calendar), now) } ?? now
    }
}

/// A saved record (or the open shift) that a past shift would collide with.
public struct PastShiftConflict: Equatable, Sendable {
    public var id: UUID
    public var start: Date
    /// nil while it is the open shift.
    public var end: Date?
}

extension DayLogModel {
    /// Every stored record that holds a shift, archived first, with whether it is the open active shift.
    private var shiftRecords: [(period: DutyPeriod, isActive: Bool)] {
        state.history.map { ($0, false) } + [(state.current, isShiftOpen)]
    }

    /// The start of a past shift: not in the future. Overlaps are not blocked here; they ask to replace.
    public func checkPastShiftStart(_ date: Date, now: Date) -> TimeEntryIssue? {
        guard storageError == nil else { return .other }
        return date > now ? .future : nil
    }

    /// The close of a past shift: after its start and not in the future.
    public func checkPastShiftEnd(_ date: Date, start: Date, now: Date) -> TimeEntryIssue? {
        guard storageError == nil else { return .other }
        if date > now { return .future }
        if date < start { return .endBeforeStart(start: start) }
        return nil
    }

    /// The records the past shift `start...end` would collide with (one shift per day, no overlap): a shift that
    /// started on the same day, or any record (the open shift included) that overlaps it. Without `end` only the
    /// start is checked. Earliest first.
    public func pastShiftConflicts(start: Date, end: Date?, now: Date, calendar: Calendar = .current) -> [PastShiftConflict] {
        let day = calendar.startOfDay(for: start)
        let span = (start: start, end: max(start, end ?? start))
        return shiftRecords.compactMap { entry -> PastShiftConflict? in
            guard let other = DayHistory.interval(of: entry.period, isActive: entry.isActive, now: now) else { return nil }
            let sameDay = entry.period.start != nil && DayHistory.recordDay(entry.period, calendar: calendar) == day
            // A point (no end yet) inside a record counts; touching edges do not.
            let inside = span.start == span.end ? other.start < span.start && span.start < other.end
                                                : DayHistory.overlaps(span, other)
            guard sameDay || inside else { return nil }
            return PastShiftConflict(id: entry.period.id, start: other.start, end: entry.isActive ? nil : other.end)
        }
        .sorted { $0.start < $1.start }
    }

    /// Saves `draft` with `drivingMinutes` as one closed shift. Refuses (false) an incomplete or invalid entry, or one
    /// that collides with a record the driver did not agree to replace. Replaced records are removed with their
    /// printouts. Everything derived (markers, the reduced-rest count, violations) follows from the records (R-E01).
    ///
    /// The latest record stays the current one. When the past shift is the latest, it becomes current with its rest
    /// running from its close, as after a normal close; the earlier current record moves to the archive with its rest
    /// ending at the past shift's start. A past shift with no later record is never judged on its rest (R-U01): the
    /// rest is measured only once a later shift exists.
    @discardableResult
    public func savePastShift(_ draft: PastShiftDraft, drivingMinutes: Int, now: Date,
                              calendar: Calendar = .current) -> Bool {
        guard storageError == nil, let end = draft.end, drivingMinutes >= 0,
              checkPastShiftStart(draft.start, now: now) == nil,
              checkPastShiftEnd(end, start: draft.start, now: now) == nil,
              draft.startPlace?.isComplete ?? true, draft.endPlace?.isComplete ?? true,
              Set(pastShiftConflicts(start: draft.start, end: end, now: now, calendar: calendar).map(\.id))
                .isSubset(of: draft.replacing),
              !(state.history + [state.current]).contains(where: { $0.id == draft.id }) else { return false }

        var shift = DutyPeriod(date: draft.start, start: draft.start, drivingMinutes: drivingMinutes, end: end,
                               isClosed: true, startPlace: draft.startPlace, endPlace: draft.endPlace)
        shift.id = draft.id
        update { journal in
            var history = journal.history.filter { !draft.replacing.contains($0.id) }
            let current = journal.current
            let currentKept = !draft.replacing.contains(current.id)
            let currentIsEmpty = current.start == nil && current.end == nil && current.drivingMinutes == nil
                && current.rests.isEmpty
            let currentKey = current.start ?? current.end ?? current.date

            if currentKept, !currentIsEmpty, currentKey > draft.start {
                // An earlier day: the current record stays current.
                history.append(shift)
                history.sortChronologically()
                journal.history = history
                Self.endFinalRest(before: shift, in: &journal.history)
            } else if history.allSatisfy({ ($0.start ?? $0.end ?? $0.date) <= draft.start }) {
                // The latest record: it becomes current, resting since its close.
                if currentKept, !currentIsEmpty {
                    var previous = current
                    if let last = previous.rests.indices.last, previous.rests[last].end == nil {
                        previous.rests[last].end = draft.start
                    }
                    history.append(previous)
                }
                history.sortChronologically()
                shift.rests = [RestSegment(start: end, kind: .daily)]
                journal.history = history
                Self.endFinalRest(before: shift, in: &journal.history)
                journal.current = shift
            } else {
                // A later archived record exists (the current one is empty, replaced or older): the current record
                // stays, and a replaced one leaves an empty current record, as on a fresh start.
                history.append(shift)
                history.sortChronologically()
                journal.history = history
                Self.endFinalRest(before: shift, in: &journal.history)
                if !currentKept { journal.current = DutyPeriod(date: now) }
            }
            for key in journal.printouts.keys where draft.replacing.contains(key.periodID) {
                journal.printouts[key] = nil
            }
        }
        return (state.history + [state.current]).contains { $0.id == draft.id }
    }

    /// The rest after the record just before `shift` cannot run past `shift`'s start.
    private static func endFinalRest(before shift: DutyPeriod, in history: inout [DutyPeriod]) {
        guard let start = shift.start,
              let index = history.lastIndex(where: { $0.id != shift.id && ($0.start ?? $0.end ?? $0.date) <= start }),
              let close = history[index].end, let last = history[index].rests.indices.last,
              history[index].rests[last].start >= close,
              history[index].rests[last].end.map({ $0 > start }) ?? true else { return }
        history[index].rests[last].end = max(close, start)
    }

    /// The deviation of the saved past shift `id` to show after saving: the earliest one, if any.
    public func pastShiftViolation(id: UUID, now: Date, calendar: Calendar = .current) -> Violation? {
        violations(now: now, calendar: calendar).filter { $0.key.periodID == id }.min { $0.began < $1.began }
    }

    /// Decision 14 for the close sheet: the red line when the past shift would pass its limit. Judged on a copy.
    public func pastShiftOverLimitLine(_ draft: PastShiftDraft, end: Date, now: Date) -> String? {
        var preview = draft
        preview.end = end
        preview.replacing.formUnion(pastShiftConflicts(start: draft.start, end: end, now: now).map(\.id))
        return Self.overLimitLine(dutyViolation(previewing: { $0.savePastShift(preview, drivingMinutes: 0, now: now) },
                                                periodID: { _ in draft.id }, now: now))
    }
}

/// The replace alert's copy (owner decision 5: ask, never overwrite silently). Short and plain.
public enum PastShiftCopy {
    public static let replaceTitle = "Replace your shift?"
    public static let replaceButton = "Replace"

    public static func replaceMessage(_ conflicts: [PastShiftConflict], calendar: Calendar = .current) -> String {
        guard conflicts.count == 1, let conflict = conflicts.first else {
            return "This overlaps \(conflicts.count) of your shifts. Replace them with this one?"
        }
        let from = HomeTimeline.dayAndTime(conflict.start, calendar: calendar)
        guard let end = conflict.end else {
            return "This overlaps your current shift from \(from). Replace it with this one?"
        }
        return "You already have a shift from \(from) to \(HomeTimeline.dayAndTime(end, calendar: calendar)). "
            + "Replace it with this one?"
    }
}
