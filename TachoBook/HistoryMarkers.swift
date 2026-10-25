//
//  HistoryMarkers.swift
//  TachoBook
//

import Foundation

/// The markers under a date in the History calendar (MVP-07, owner decisions 2–4, 24.10.2026).
/// The violation marker ("!") comes with the violations task.
public struct HistoryDayMarkers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Bed: the Home row counts a new reduced daily rest (9 h ≤ rest < 11 h) on this day.
    public static let reducedRest = HistoryDayMarkers(rawValue: 1 << 0)
    /// Steering wheel: the day's shift has extended driving (more than 9 h, up to 10 h).
    public static let extendedDriving = HistoryDayMarkers(rawValue: 1 << 1)

    /// VoiceOver names the markers after the date, e.g. "reduced rest, extended driving".
    public var spokenNames: [String] {
        var names: [String] = []
        if contains(.reducedRest) { names.append("reduced rest") }
        if contains(.extendedDriving) { names.append("extended driving") }
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

    /// Markers for `day`. The bed sits where the Home row's count gains a reduction (the day its rest ended,
    /// or the shift day once its duty passes 13 h), so it matches the history row of PR #13.
    public func historyMarkers(on day: Date, now: Date, calendar: Calendar = .current) -> HistoryDayMarkers {
        let start = calendar.startOfDay(for: day)
        guard start <= calendar.startOfDay(for: now) else { return [] }
        var markers: HistoryDayMarkers = []
        if HistoryMarkers.isExtendedDriving(minutes: historyRecord(on: start, calendar: calendar)?.drivingMinutes) {
            markers.insert(.extendedDriving)
        }
        if let today = reductionIDs(endOf: start, now: now, calendar: calendar), !today.isEmpty {
            let previous = calendar.date(byAdding: .day, value: -1, to: start)
                .flatMap { reductionIDs(endOf: $0, now: now, calendar: calendar) } ?? []
            if !today.isSubset(of: previous) { markers.insert(.reducedRest) }
        }
        return markers
    }

    /// Markers for every day from the first record up to today; days without markers are left out.
    /// Derived from the stored records on every call, so it follows each history edit.
    public func historyMarkers(now: Date, calendar: Calendar = .current) -> [Date: HistoryDayMarkers] {
        let periods = state.history + [state.current]
        let today = calendar.startOfDay(for: now)
        guard let first = periods.compactMap({ $0.start ?? $0.end }).min() else { return [:] }
        var result: [Date: HistoryDayMarkers] = [:]
        var day = min(calendar.startOfDay(for: first), today)
        while day <= today {
            let markers = historyMarkers(on: day, now: now, calendar: calendar)
            if !markers.isEmpty { result[day] = markers }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
