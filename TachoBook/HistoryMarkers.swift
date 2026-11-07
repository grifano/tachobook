//
//  HistoryMarkers.swift
//  TachoBook
//

import Foundation

/// The markers under a date in the History calendar (MVP-07, owner decisions 2–4, 24.10.2026; the violation
/// marker from the violation counter, decision 20, 07.11.2026).
public struct HistoryDayMarkers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Bed: the Home row counts a new reduction on this day — a reduced daily rest (9 h ≤ rest < 11 h), or any
    /// rest after a shift past 13 h without a confirmed split (decision 1, 30.10.2026).
    public static let reducedRest = HistoryDayMarkers(rawValue: 1 << 0)
    /// Steering wheel: the day's shift has extended driving (more than 9 h, up to 10 h).
    public static let extendedDriving = HistoryDayMarkers(rawValue: 1 << 1)
    /// Red "!": a deviation recorded for the day's shift (its duty past the limit, or its rest under 9 h).
    public static let violation = HistoryDayMarkers(rawValue: 1 << 2)

    /// VoiceOver names the markers after the date, e.g. "reduced rest, extended driving".
    public var spokenNames: [String] {
        var names: [String] = []
        if contains(.reducedRest) { names.append("reduced rest") }
        if contains(.extendedDriving) { names.append("extended driving") }
        if contains(.violation) { names.append("rule broken") }
        return names
    }
}

public enum HistoryMarkers {
    /// Daily driving over 9 h and up to 10 h (R-D01 extension). Longer driving is a violation (later task).
    public static let extendedDrivingMinutes = (9 * 60 + 1)...(10 * 60)

    public static func isExtendedDriving(minutes: Int?) -> Bool {
        minutes.map(extendedDrivingMinutes.contains) ?? false
    }
}

extension DayLogModel {
    /// The record the History sheet shows for `day`: the shift that started on it (a shift across midnight
    /// stays on its start date). Today's open shift counts too, as on Home.
    public func historyRecord(on day: Date, calendar: Calendar = .current) -> DutyPeriod? {
        let current = state.current
        if current.start != nil, DayHistory.recordDay(current, calendar: calendar) == calendar.startOfDay(for: day) {
            return current
        }
        return dayRecord(on: day, calendar: calendar)
    }

    /// Markers for `day`. The bed sits on the day of the shift whose following rest is reduced (Serhii,
    /// 25.10.2026): the shift day, not the day the rest ended. A shift past 13 h shows it while its rest runs.
    public func historyMarkers(on day: Date, now: Date, calendar: Calendar = .current) -> HistoryDayMarkers {
        historyMarkers(on: day, now: now, violationDays: Set(violations(now: now, calendar: calendar).map(\.day)),
                       calendar: calendar)
    }

    private func historyMarkers(on day: Date, now: Date, violationDays: Set<Date>, calendar: Calendar) -> HistoryDayMarkers {
        let start = calendar.startOfDay(for: day)
        guard start <= calendar.startOfDay(for: now) else { return [] }
        var markers: HistoryDayMarkers = []
        if HistoryMarkers.isExtendedDriving(minutes: historyRecord(on: start, calendar: calendar)?.drivingMinutes) {
            markers.insert(.extendedDriving)
        }
        let shiftsOfDay = Set((state.history + [state.current])
            .filter { $0.start != nil && DayHistory.recordDay($0, calendar: calendar) == start }.map(\.id))
        if let reductions = historyReductionIDs(onDay: start, now: now, calendar: calendar),
           !reductions.isDisjoint(with: shiftsOfDay) {
            markers.insert(.reducedRest)
        }
        if violationDays.contains(start) { markers.insert(.violation) }
        return markers
    }

    /// Reduced rests used since the last weekly rest as the History sheet shows them for `day` (Serhii,
    /// 25.10.2026): every reduction up to that day, including the rest after that day's own shift once it is
    /// reduced. nil while the count is unknown.
    public func historyReducedRests(onDay day: Date, now: Date, calendar: Calendar = .current) -> Int? {
        historyReductionIDs(onDay: day, now: now, calendar: calendar)?.count
    }

    /// The reductions behind `historyReducedRests`, each named by the shift whose following rest it is.
    /// The records of `day` and earlier are counted together with the rest after the last of them: it ends at
    /// the next shift's start (or runs up to `now`).
    func historyReductionIDs(onDay day: Date, now: Date, calendar: Calendar = .current) -> Set<UUID>? {
        let start = calendar.startOfDay(for: day)
        let all = ReducedRestCounter.timeline(state.history + [state.current])
        var records = all.filter { DayHistory.recordDay($0, calendar: calendar) <= start }
        guard let last = records.last else { return nil }
        var instant = now
        if let index = all.firstIndex(where: { $0.id == last.id }), index + 1 < all.count,
           let anchor = last.start, let restStart = last.end, let restEnd = all[index + 1].start {
            let rest = ReducedRestCounter.classify(anchor: anchor, pauses: ReducedRestCounter.pauses(of: last),
                                                   restStart: restStart, restEnd: restEnd)
            // Judged when the rest ended. A weekly rest after a shift past 13 h then still counts as the pending
            // reduction of that shift (decisions of 26.10.2026 and 30.10.2026).
            instant = restEnd
            // Only the next shift's start closes a daily rest; its own close and rests belong to its own day.
            // A weekly rest starts the next week, so the next shift is left out: its count starts from 0.
            if rest != .weekly {
                var opening = all[index + 1]
                opening.end = nil
                opening.isClosed = false
                opening.rests = []
                records.append(opening)
            }
        }
        guard let latest = records.last else { return nil }
        return ReducedRestCounter.shownReductionIDs(periods: records, latest: latest, now: instant)
    }

    /// Markers for every day from the first record up to today; days without markers are left out.
    /// Derived from the stored records on every call, so it follows each history edit.
    public func historyMarkers(now: Date, calendar: Calendar = .current) -> [Date: HistoryDayMarkers] {
        let periods = state.history + [state.current]
        let today = calendar.startOfDay(for: now)
        guard let first = periods.compactMap({ $0.start ?? $0.end }).min() else { return [:] }
        var result: [Date: HistoryDayMarkers] = [:]
        var day = min(calendar.startOfDay(for: first), today)
        let violationDays = Set(violations(now: now, calendar: calendar).map(\.day))
        while day <= today {
            let markers = historyMarkers(on: day, now: now, violationDays: violationDays, calendar: calendar)
            if !markers.isEmpty { result[day] = markers }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
