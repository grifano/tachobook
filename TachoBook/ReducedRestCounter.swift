//
//  ReducedRestCounter.swift
//  TachoBook
//

import Foundation

/// How a completed final rest after a duty period counts (R-D02, R-D03, R-W01).
public enum CompletedRestClass: Equatable, Sendable {
    /// At least 11 h inside the 24 h window.
    case regular
    /// A confirmed pause of 3 h or more, then at least 9 h, both inside the window: regular, not reduced.
    case split
    /// 9 h up to less than 11 h inside the window, without a valid split.
    case reduced
    /// Less than 9 h inside the window: below the baseline, not a reduction.
    case shortfall
    /// 24 h or more: a weekly-rest boundary that starts a new count.
    case weekly
}

/// Whether the 15 h duty marker (9 h final rest) is available for the current daily period (R-D05).
public enum DutyLimitAvailability: Equatable, Sendable {
    /// Count 0–2, or a confirmed split-first pause of 3 h or more.
    case fifteenHours
    /// Three or more reductions used and no split: the rest must be 11 h.
    case thirteenHoursOnly
    /// The count is unknown (or an unconfirmed pause leaves the split open) — never shown as available.
    case unknown

    /// Hours of duty after the anchor by which the final rest must start; nil while unknown.
    public var latestRestStartHours: Int? {
        switch self {
        case .fifteenHours: 15
        case .thirteenHoursOnly: 13
        case .unknown: nil
        }
    }
}

/// Pure count of reduced daily rests since the last completed weekly rest (R-D04), from saved records only.
/// Hours are elapsed seconds (R-T01); every threshold is inclusive.
public enum ReducedRestCounter {
    /// Reduced daily rests allowed between two weekly rests.
    public static let limit = 3

    static let window: TimeInterval = 24 * 3600
    static let regularRest: TimeInterval = 11 * 3600
    static let reducedRest: TimeInterval = 9 * 3600
    static let splitFirst: TimeInterval = 3 * 3600
    static let weeklyRest: TimeInterval = 24 * 3600

    /// Pauses before the last close of a duty period (Close → Resume), which can be a split first part.
    static func pauses(of period: DutyPeriod) -> [RestSegment] {
        period.rests.filter { rest in
            guard rest.end != nil else { return false }
            return period.end.map { rest.start < $0 } ?? true
        }
    }

    /// Seconds of `start...end` that fall inside the window `anchor...anchor + 24 h`.
    static func secondsInWindow(start: Date, end: Date, anchor: Date) -> TimeInterval {
        let windowEnd = anchor.addingTimeInterval(window)
        return max(0, min(end, windowEnd).timeIntervalSince(max(start, anchor)))
    }

    /// Only a pause the driver confirmed as rest qualifies; an unknown one never confirms a split (V08).
    static func isSplitFirst(_ pause: RestSegment, anchor: Date, confirmedOnly: Bool = true) -> Bool {
        guard let end = pause.end, !confirmedOnly || pause.dailyRestConfirmed == true else { return false }
        return secondsInWindow(start: pause.start, end: end, anchor: anchor) >= splitFirst
    }

    /// Classifies a completed final rest that started after a duty period anchored at `anchor`
    /// (the end of the previous rest, recorded as the period start).
    public static func classify(anchor: Date, pauses: [RestSegment], restStart: Date, restEnd: Date) -> CompletedRestClass {
        if restEnd.timeIntervalSince(restStart) >= weeklyRest { return .weekly }
        return classifyInWindow(anchor: anchor, pauses: pauses, restStart: restStart, restEnd: restEnd)
    }

    /// How the part of a rest inside the 24 h window counts as the daily rest of the duty period before it,
    /// whatever the rest's full length: a rest that runs on into a weekly rest is still judged in its window
    /// (R-D02, R-W01; decision 26.10.2026). Never `.weekly`.
    public static func classifyInWindow(anchor: Date, pauses: [RestSegment], restStart: Date, restEnd: Date) -> CompletedRestClass {
        let inWindow = secondsInWindow(start: restStart, end: restEnd, anchor: anchor)
        if inWindow >= regularRest { return .regular }
        guard inWindow >= reducedRest else { return .shortfall }
        return pauses.contains { isSplitFirst($0, anchor: anchor) } ? .split : .reduced
    }

    /// Reduced daily rests used since the last completed rest of 24 h or more; nil (unknown, not 0)
    /// when the records contain no such boundary or a rest after it cannot be measured.
    /// A rest is counted once, when it ends: the rest after the latest record is still running.
    public static func usedCount(periods: [DutyPeriod]) -> Int? {
        reducedPeriodIDs(periods: periods)?.count
    }

    /// The records whose completed rest counts as reduced since the last weekly rest, newest first;
    /// nil when `usedCount` is unknown.
    static func reducedPeriodIDs(periods: [DutyPeriod]) -> [UUID]? {
        let timed = timeline(periods)
        var reduced: [UUID] = []
        for index in timed.indices.dropLast().reversed() {
            let period = timed[index]
            guard let anchor = period.start, let restStart = period.end,
                  let restEnd = timed[index + 1].start else { return nil }
            switch classify(anchor: anchor, pauses: pauses(of: period), restStart: restStart, restEnd: restEnd) {
            case .weekly: return reduced
            case .reduced: reduced.append(period.id)
            case .regular, .split, .shortfall: break
            }
        }
        return nil
    }

    /// The reductions behind `shownCount`: each named by the record whose rest it is, the pending one included.
    /// nil while the count is unknown.
    public static func shownReductionIDs(periods: [DutyPeriod], latest: DutyPeriod, now: Date) -> Set<UUID>? {
        guard let reduced = reducedPeriodIDs(periods: periods) else { return nil }
        let pending = workCardCount(used: reduced.count, period: latest, now: now).map { $0 > reduced.count } ?? false
        return Set(reduced + (pending ? [latest.id] : []))
    }

    /// Records in time order. Records with no times (for example a driving-only entry) take no part.
    static func timeline(_ periods: [DutyPeriod]) -> [DutyPeriod] {
        periods
            .compactMap { period -> (key: Date, period: DutyPeriod)? in
                guard let key = period.start ?? period.end else { return nil }
                return (key, period)
            }
            .sorted { $0.key < $1.key }
            .map(\.period)
    }

    /// Used (blue) icons of the Home row (beds and hammers alike): the completed count plus the reduction the latest
    /// record's duty past 13 h already makes certain, never a fourth. nil while the count is unknown.
    public static func shownCount(periods: [DutyPeriod], latest: DutyPeriod, now: Date) -> Int? {
        let used = usedCount(periods: periods)
        return workCardCount(used: used, period: latest, now: now) ?? used
    }

    /// Duty past which an 11 h rest no longer fits in the 24 h window (owner decision 12, 20.10.2026).
    static let pendingAfter: TimeInterval = 13 * 3600

    /// Whether the rest after `period` is already certain to be reduced (or a deviation): its duty
    /// (start to close, or to `now` while open) is past 13 h and it has no confirmed split-first pause.
    /// Once the rest has reached 24 h its window is over, so its part inside the window decides: 9 h up to
    /// less than 11 h stays a reduction even though the rest becomes weekly (decision 26.10.2026).
    public static func isReductionPending(period: DutyPeriod, now: Date) -> Bool {
        guard let anchor = period.start else { return false }
        let close = period.end ?? now
        guard close.timeIntervalSince(anchor) > pendingAfter else { return false }
        if period.end != nil, now.timeIntervalSince(close) >= weeklyRest {
            return classifyInWindow(anchor: anchor, pauses: pauses(of: period), restStart: close, restEnd: now) == .reduced
        }
        return !pauses(of: period).contains { isSplitFirst($0, anchor: anchor) }
    }

    /// The completed count plus the pending reduction of the current shift, never a fourth.
    /// nil when the count is unknown or no reduction is pending. The stored count is unchanged.
    public static func workCardCount(used: Int?, period: DutyPeriod, now: Date) -> Int? {
        guard let used, isReductionPending(period: period, now: now) else { return nil }
        return used >= limit ? used : used + 1
    }

    /// R-D05 for the daily period anchored at `period.start`.
    public static func availability(used: Int?, period: DutyPeriod) -> DutyLimitAvailability {
        guard let anchor = period.start else { return .unknown }
        let pauses = pauses(of: period)
        if pauses.contains(where: { isSplitFirst($0, anchor: anchor) }) { return .fifteenHours }
        // A long pause not confirmed as rest may or may not be a split (V08).
        let openSplit = pauses.contains { isSplitFirst($0, anchor: anchor, confirmedOnly: false) }
        guard let used else { return .unknown }
        if used < limit { return .fifteenHours }
        return openSplit ? .unknown : .thirteenHoursOnly
    }
}

extension DayLogModel {
    private var countedPeriods: [DutyPeriod] { state.history + [state.current] }

    /// Reduced daily rests used since the last completed weekly rest; nil while unknown (R-U01, P2).
    /// Derived from saved records, so it follows every history edit (R-E01) and relaunch.
    public var reducedRestsUsed: Int? { ReducedRestCounter.usedCount(periods: countedPeriods) }

    /// The count including the reduction the current shift's duty past 13 h already makes certain (decision 12);
    /// nil when none is pending or the count is unknown. Follows history edits (R-E01).
    public func workCardReducedRests(now: Date) -> Int? {
        ReducedRestCounter.workCardCount(used: reducedRestsUsed, period: state.current, now: now)
    }

    /// During the rest after a shift past 13 h the reduction is already shown (Serhii, 20.10.2026); otherwise
    /// the completed count, which changes when the rest ends. nil while unknown.
    public func restCardReducedRests(now: Date) -> Int? {
        workCardReducedRests(now: now) ?? reducedRestsUsed
    }

    /// Used (blue) icons of today's Home row, the same on the Rest (beds) and Work (hammers) views; nil while
    /// the count is unknown, shown as all gray. The row itself is always visible (owner decisions 1–3, 23.10.2026).
    public func homeReducedRests(now: Date) -> Int? {
        restCardReducedRests(now: now)
    }

    /// The Home row of a past `day` as it stood at the end of that day (owner decision 5): only the records
    /// of that day and earlier, judged at its last second. Derived on every read, so it follows history edits.
    public func reducedRests(endOf day: Date, now: Date, calendar: Calendar = .current) -> Int? {
        let start = calendar.startOfDay(for: day)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let records = countedPeriods.filter { DayHistory.recordDay($0, calendar: calendar) <= start }
        guard let latest = ReducedRestCounter.timeline(records).last else { return nil }
        return ReducedRestCounter.shownCount(periods: records, latest: latest,
                                             now: min(now, next.addingTimeInterval(-1)))
    }

    /// 13 vs 15 h for the current duty period (R-D05), for the Work card markers and the Resume flow.
    public var dutyLimitAvailability: DutyLimitAvailability {
        ReducedRestCounter.availability(used: reducedRestsUsed, period: state.current)
    }
}
