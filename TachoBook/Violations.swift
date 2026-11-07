//
//  Violations.swift
//  TachoBook
//

import Foundation

/// The two v1 deviations from the baseline rules that saved records can show (MVP-08; owner decision 1, 19.10.2026).
/// They are deviations "per your records", never a legal finding (P1).
public enum ViolationKind: String, Codable, Sendable, CaseIterable {
    /// The duty period ran past its applicable 13 h or 15 h limit (R-D05). Covers a fourth reduced rest (V05).
    case dutyLimit
    /// The daily rest after a duty period had less than 9 h inside its 24 h window (R-D02, R-D07, V04).
    case shortRest
}

/// Names one violation across recomputations: the record it belongs to and its kind. The printout is stored by it,
/// so it survives relaunch and history edits (R-E01).
public struct ViolationKey: Hashable, Sendable {
    public var periodID: UUID
    public var kind: ViolationKind

    public init(periodID: UUID, kind: ViolationKind) {
        self.periodID = periodID
        self.kind = kind
    }

    /// The form saved in the store.
    var storageID: String { "\(periodID.uuidString)|\(kind.rawValue)" }

    init?(storageID: String) {
        let parts = storageID.split(separator: "|")
        guard parts.count == 2, let id = UUID(uuidString: String(parts[0])),
              let kind = ViolationKind(rawValue: String(parts[1])) else { return nil }
        self.init(periodID: id, kind: kind)
    }
}

/// One deviation found in the saved records, measured at `now`.
public struct Violation: Identifiable, Equatable, Sendable {
    public var key: ViolationKey
    public var id: ViolationKey { key }
    public var kind: ViolationKind { key.kind }
    /// The day of the duty period (its start date; a shift across midnight stays on its start date), as on Home
    /// and in History.
    public var day: Date
    /// When it began: the moment the limit passed, or the start of the short rest. A printout cannot be earlier
    /// (decision 19).
    public var began: Date
    /// 13 or 15 for a duty limit; 9 for a short rest.
    public var limitHours: Int
    /// The duty period's start: the anchor of its 24 h window.
    public var dutyStart: Date
    /// Duty from start to close, or to now while the shift is still open.
    public var dutySeconds: Int
    /// Duty limit: the rest time inside the window is not used (0). Short rest: the rest inside the 24 h window.
    public var restSeconds: Int
    /// The shift is still open and the overtime keeps growing.
    public var isOngoing: Bool

    /// Duty past the limit; 0 for a short rest.
    public var overtimeSeconds: Int {
        kind == .dutyLimit ? max(0, dutySeconds - limitHours * 3600) : 0
    }
}

/// Pure detection from saved records (R-D02, R-D05, R-D07, R-U01). Hours are elapsed seconds (R-T01).
public enum ViolationRules {
    static let window: TimeInterval = 24 * 3600
    static let minimumRest: TimeInterval = 9 * 3600

    /// The applicable duty limit (R-D05): 13 h at 3 of 3 without a confirmed split, otherwise 15 h. While the count
    /// is unknown the limit is 13 h or 15 h, so only a duty past 15 h is certain to pass it (R-U01: between 13 h and
    /// 15 h it stays unknown, never a deviation). The same hours as the Home gauge.
    public static func applicableLimitHours(_ availability: DutyLimitAvailability) -> Int {
        HomeTimeline.dutyGaugeHours(availability)
    }

    /// Every deviation in `periods`, newest first. `currentID` is the record whose open shift or running rest is
    /// measured up to `now`. `only` limits the work to one record.
    public static func violations(periods: [DutyPeriod], currentID: UUID, now: Date, only: UUID? = nil,
                                  calendar: Calendar = .current) -> [Violation] {
        let timed = ReducedRestCounter.timeline(periods)
        var found: [Violation] = []
        for index in timed.indices {
            let period = timed[index]
            guard only.map({ $0 == period.id }) ?? true, let anchor = period.start else { continue }
            let isCurrent = period.id == currentID
            let day = DayHistory.recordDay(period, calendar: calendar)

            // Duty past the limit: close time, or now while the current shift is open. An archived record without a
            // close is incomplete: unknown, not a deviation.
            if let dutyEnd = period.end ?? (isCurrent ? now : nil) {
                let used = ReducedRestCounter.usedCount(periods: Array(timed[...index]))
                let limit = applicableLimitHours(ReducedRestCounter.availability(used: used, period: period))
                let limitEnd = HomeTimeline.adding(hours: limit, to: anchor)
                if dutyEnd > limitEnd {
                    found.append(Violation(
                        key: ViolationKey(periodID: period.id, kind: .dutyLimit), day: day, began: limitEnd,
                        limitHours: limit, dutyStart: anchor,
                        dutySeconds: HomeTimeline.elapsedSeconds(from: anchor, to: dutyEnd), restSeconds: 0,
                        isOngoing: isCurrent && period.end == nil))
                }
            }

            // The final rest after the last close. Pauses before a Resume are not rests of their own (V09).
            if let restStart = period.end, let inWindow = restInWindow(after: period, at: index, in: timed,
                                                                      isCurrent: isCurrent, now: now),
               inWindow < minimumRest {
                found.append(Violation(
                    key: ViolationKey(periodID: period.id, kind: .shortRest), day: day, began: restStart,
                    limitHours: Int(minimumRest / 3600), dutyStart: anchor,
                    dutySeconds: HomeTimeline.elapsedSeconds(from: anchor, to: restStart),
                    restSeconds: Int(inWindow), isOngoing: false))
            }
        }
        return found.sorted { ($0.began, $0.kind.rawValue) > ($1.began, $1.kind.rawValue) }
    }

    /// The rest after `period` inside its 24 h window, once it is final: the next shift started, or the window has
    /// ended while the rest still runs (live classification stays provisional until then). nil while unknown.
    static func restInWindow(after period: DutyPeriod, at index: Int, in timed: [DutyPeriod],
                             isCurrent: Bool, now: Date) -> TimeInterval? {
        guard let anchor = period.start, let restStart = period.end else { return nil }
        if index + 1 < timed.count {
            guard let restEnd = timed[index + 1].start else { return nil }
            return ReducedRestCounter.secondsInWindow(start: restStart, end: restEnd, anchor: anchor)
        }
        let windowEnd = anchor.addingTimeInterval(window)
        guard isCurrent, now >= windowEnd else { return nil }
        return ReducedRestCounter.secondsInWindow(start: restStart, end: now, anchor: anchor)
    }
}

// MARK: - 56-day carry period (spec G.1; owner decisions 15–17, 01.11 and 02.11.2026)

/// How long the driver carries a printout: the printout day plus 56 calendar days (Reg. (EU) 165/2014 Art. 36).
/// Calendar days in the phone's current time zone. About carrying the printout only: the violation stays in the records.
public enum PrintoutCarry {
    public static let days = 56

    /// Where a violation sits in the Violations tab and what its counter shows.
    public struct Status: Equatable, Sendable {
        /// The last day the printout must be carried; nil while no printout is marked ("?").
        public var carryUntil: Date?
        /// Whole days from today to `carryUntil`: 56 on the printout day, 0 on `carryUntil`. nil while no printout.
        public var daysLeft: Int?
        /// In the gray "Older than 56 days" group.
        public var isOlder: Bool
    }

    /// The printout day + 56 calendar days (midnight).
    public static func carryUntil(printedAt: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: printedAt)
        return calendar.date(byAdding: .day, value: days, to: day) ?? day.addingTimeInterval(TimeInterval(days) * 86_400)
    }

    /// With a printout the group follows `carryUntil` (decision 16); without one the violation moves to the gray
    /// group the day after its date + 56 days and keeps "?" (decision 17).
    public static func status(violationDay: Date, printedAt: Date?, now: Date, calendar: Calendar = .current) -> Status {
        let today = calendar.startOfDay(for: now)
        guard let printedAt else {
            let last = carryUntil(printedAt: violationDay, calendar: calendar)
            return Status(carryUntil: nil, daysLeft: nil, isOlder: today > last)
        }
        let until = carryUntil(printedAt: printedAt, calendar: calendar)
        let left = calendar.dateComponents([.day], from: today, to: until).day ?? 0
        return Status(carryUntil: until, daysLeft: left, isOlder: left < 0)
    }
}

// MARK: - Model

extension DayLogModel {
    private var allRecords: [DutyPeriod] { state.history + [state.current] }

    /// Every violation in the saved records, newest first. Derived on every read, so it follows each history edit
    /// (R-E01) and relaunch.
    public func violations(now: Date, calendar: Calendar = .current) -> [Violation] {
        ViolationRules.violations(periods: allRecords, currentID: state.current.id, now: now, calendar: calendar)
    }

    /// The violation named by `key`, if the records still show it.
    public func violation(for key: ViolationKey, now: Date, calendar: Calendar = .current) -> Violation? {
        ViolationRules.violations(periods: allRecords, currentID: state.current.id, now: now, only: key.periodID,
                                  calendar: calendar)
            .first { $0.key == key }
    }

    /// The current shift past its applicable limit (Home: red overtime, limit-passed alert).
    public func currentDutyViolation(now: Date) -> Violation? {
        violation(for: ViolationKey(periodID: state.current.id, kind: .dutyLimit), now: now)
    }

    /// When the printout for `key` was made; nil while none is marked.
    public func printout(for key: ViolationKey) -> Date? { state.printouts[key] }

    /// Decision 19: not earlier than the moment the violation began, not later than now.
    public func checkPrintout(_ date: Date, for violation: Violation, now: Date) -> TimeEntryIssue? {
        if date > now { return .future }
        if date < violation.began { return .printoutTooEarly(violation.began, violation.kind) }
        return nil
    }

    /// Printout done (decision 16): the 56 days count from `date`'s day.
    public func markPrintout(_ date: Date, for violation: Violation, now: Date) {
        guard checkPrintout(date, for: violation, now: now) == nil else { return }
        update { $0.printouts[violation.key] = date }
    }

    /// Mark as not done: the printout time is cleared and the counter shows "?" again.
    public func clearPrintout(for key: ViolationKey) {
        guard state.printouts[key] != nil else { return }
        update { $0.printouts[key] = nil }
    }

    /// The Violations tab status of `violation` at `now`.
    public func carryStatus(of violation: Violation, now: Date, calendar: Calendar = .current) -> PrintoutCarry.Status {
        PrintoutCarry.status(violationDay: violation.day, printedAt: printout(for: violation.key), now: now,
                             calendar: calendar)
    }

    // MARK: Time sheets over the limit (decision 14)

    /// The duty-limit violation the record `periodID` would have after `change`, judged on a copy: nothing is saved.
    /// `periodID` reads the affected record from the changed copy (a new shift has a new id). nil when the duty
    /// stays within its applicable limit, or the limit is unknown (R-U01).
    public func dutyViolation(previewing change: (DayLogModel) -> Void, periodID: (DayLogModel) -> UUID?,
                              now: Date) -> Violation? {
        let copy = DayLogModel(journal: state)
        change(copy)
        guard let id = periodID(copy) else { return nil }
        return copy.violation(for: ViolationKey(periodID: id, kind: .dutyLimit), now: now)
    }

    /// The red line of a time sheet whose time would push the shift past its limit (decision 14).
    public static func overLimitLine(_ violation: Violation?) -> String? {
        guard let violation, violation.kind == .dutyLimit else { return nil }
        return "This shift passes your \(violation.limitHours)-hour limit by "
            + "\(DayLogModel.durationString(seconds: violation.overtimeSeconds))."
    }
}
