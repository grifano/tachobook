//
//  DayLogModel.swift
//  TachoBook
//

import Foundation
import Observation

public enum LogEntryType: Hashable, Sendable {
    case dayStart
    case driving
    case dayEnd
}

@Observable
public final class DayLogModel {
    private var state: ShiftJournal
    @ObservationIgnored private var store: ShiftStore?
    public private(set) var storageError: String?

    public var selectedDate: Date { state.current.date }
    public var dayStart: Date? { state.current.start }
    public var drivingMinutes: Int? { state.current.drivingMinutes }
    public var dayEnd: Date? { state.current.end }
    public var isDayClosed: Bool { state.current.isClosed }
    public var dutyID: UUID { state.current.id }
    public var restSegments: [RestSegment] { state.current.rests }
    public var archivedPeriods: [DutyPeriod] { state.history }
    public var isResting: Bool { state.current.rests.last?.end == nil && !state.current.rests.isEmpty }
    public var isShiftOpen: Bool { dayStart != nil && !isResting }

    /// Tests/previews are in-memory unless a disk store URL is explicitly supplied.
    /// A failed disk store is locked, never replaced with an in-memory fallback.
    public init(date: Date = Date(), storageURL: URL? = nil, legacyURL: URL? = nil) {
        state = ShiftJournal(current: DutyPeriod(date: date))
        if let storageURL {
            do {
                let store = try ShiftStore(url: storageURL)
                if let saved = try store.load(legacyURL: legacyURL) { state = saved }
                self.store = store
            } catch {
                storageError = "Saved shift could not be opened: \(error.localizedDescription)"
            }
        }
    }

    public static func dashboardModel() -> DayLogModel {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-sampleData") { return DayLogModel() }
        #if DEBUG
        if args.contains("-persistenceUITest") {
            let url = URL.applicationSupportDirectory.appending(path: "TachoBook/persistence-ui/shifts.store")
            if args.contains("-resetPersistenceTest") {
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            }
            // Deliberately empty: relaunch checks must never reseed missing data.
            return DayLogModel(storageURL: url)
        }
        if args.contains("-timerUITest") {
            let url = URL.applicationSupportDirectory.appending(path: "TachoBook/ui-test-shifts.store")
            if args.contains("-resetTimerTest") {
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(atPath: url.path + suffix)
                }
            }
            let model = DayLogModel(storageURL: url)
            if model.dayStart == nil {
                if args.contains("-longRestUITest") {
                    model.setDayStart(Date().addingTimeInterval(-16 * 3600))
                    model.setDrivingMinutes(120)
                    model.closeShift(at: Date().addingTimeInterval(-11 * 3600))
                } else {
                    model.setDayStart(Date().addingTimeInterval(-3661))
                    model.setDrivingMinutes(120)
                }
            }
            return model
        }
        #endif
        return DayLogModel(storageURL: defaultStorageURL, legacyURL: legacyStorageURL)
    }

    public static var defaultStorageURL: URL {
        URL.applicationSupportDirectory.appending(path: "TachoBook/shifts-v1.store")
    }

    public static var legacyStorageURL: URL {
        URL.applicationSupportDirectory.appending(path: "TachoBook/shift-journal-v1.json")
    }

    private func update(_ change: (inout ShiftJournal) -> Void) {
        // Preserve an unreadable journal instead of overwriting it with an empty state.
        guard storageError == nil else { return }
        var next = state
        change(&next)
        if let store {
            do {
                try store.save(next)
            } catch {
                storageError = "Shift could not be saved: \(error.localizedDescription)"
                return
            }
        }
        state = next
    }

    public func shiftElapsedSeconds(at now: Date) -> Int? {
        guard let start = dayStart else { return nil }
        let stop = isResting ? state.current.rests.last!.start : now
        return max(0, Int(stop.timeIntervalSince(start)))
    }

    public func restElapsedSeconds(at now: Date) -> Int {
        guard isResting, let rest = restSegments.last else { return 0 }
        return max(0, Int(now.timeIntervalSince(rest.start)))
    }

    public static func durationString(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }

    public func shiftDurationString(at now: Date) -> String {
        Self.durationString(seconds: shiftElapsedSeconds(at: now) ?? 0)
    }

    public func shiftSecondsString(at now: Date) -> String {
        String(format: "%02d", (shiftElapsedSeconds(at: now) ?? 0) % 60)
    }

    public func restMilestone(hours: Int) -> Date? {
        guard isResting, let rest = restSegments.last else { return nil }
        return rest.start.addingTimeInterval(Double(hours) * 3600)
    }

    /// Records an actual continuation; does not claim legal eligibility.
    public func resumeShift(at date: Date) {
        guard isResting, let rest = restSegments.last, date >= rest.start else { return }
        update { journal in
            journal.current.rests[journal.current.rests.count - 1].end = date
            journal.current.end = nil
            journal.current.isClosed = false
        }
    }

    /// Qualification is an explicit external decision, never inferred from a timer.
    public func startNewShift(at date: Date, dailyRestConfirmed: Bool) {
        guard dailyRestConfirmed, isResting, let rest = restSegments.last,
              date.timeIntervalSince(rest.start) >= 9 * 3600 else { return }
        update { journal in
            journal.current.rests[journal.current.rests.count - 1].end = date
            journal.current.rests[journal.current.rests.count - 1].dailyRestConfirmed = true
            journal.history.append(journal.current)
            journal.current = DutyPeriod(date: date, start: date)
        }
    }

    public static func defaultReferenceDate() -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 20
        comps.hour = 6
        comps.minute = 30
        return Calendar.current.date(from: comps) ?? Date()
    }

    public static func defaultDayEndReferenceDate() -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 20
        comps.hour = 20
        comps.minute = 30
        return Calendar.current.date(from: comps) ?? Date()
    }

    public var workingMinutes: Int? {
        guard let start = dayStart, let end = dayEnd else { return nil }
        let diff = Int(end.timeIntervalSince(start) / 60)
        return max(0, diff)
    }

    public var workingFraction: Double {
        // Visual scale only; this timer does not evaluate work/rest eligibility.
        let totalLimit: Double = 15 * 60
        guard let current = workingMinutes else {
            return 0.0
        }
        return min(1.0, Double(current) / totalLimit)
    }

    public var workingTimeString: String {
        if let minutes = workingMinutes {
            let h = minutes / 60
            let m = minutes % 60
            return String(format: "%d:%02d", h, m)
        } else if dayStart != nil {
            return "0:00"
        } else {
            return "0:00"
        }
    }

    public var restTimeString: String {
        Self.durationString(seconds: restElapsedSeconds(at: Date()))
    }

    public var restFraction: Double {
        min(1, Double(restElapsedSeconds(at: Date())) / (11 * 3600))
    }

    public var canCloseDay: Bool {
        dayStart != nil && drivingMinutes != nil && dayEnd != nil
    }

    public var dayStartDisplayString: String {
        guard let dayStart else { return "-" }
        return dayStart.formatted(date: .omitted, time: .shortened)
    }

    public var dayEndDisplayString: String {
        guard let dayEnd else { return "-" }
        return dayEnd.formatted(date: .omitted, time: .shortened)
    }

    public var dayStartFullDisplayString: String {
        guard let dayStart else { return "-" }
        let timePart = dayStart.formatted(date: .omitted, time: .shortened)
        let datePart = dayStart.formatted(Date.FormatStyle().day().month(.wide))
        return "\(datePart), \(timePart)"
    }

    public var dayEndFullDisplayString: String {
        guard let dayEnd else { return "-" }
        let timePart = dayEnd.formatted(date: .omitted, time: .shortened)
        let datePart = dayEnd.formatted(Date.FormatStyle().day().month(.wide))
        return "\(datePart), \(timePart)"
    }

    public var drivingDisplayString: String {
        guard let drivingMinutes else { return "-" }
        let h = drivingMinutes / 60
        let m = drivingMinutes % 60
        return String(format: "%dH%02dM", h, m)
    }

    public var drivingInputString: String {
        guard let drivingMinutes else { return "0h00" }
        let h = drivingMinutes / 60
        let m = drivingMinutes % 60
        return String(format: "%dh%02d", h, m)
    }

    public func setDayStart(_ date: Date) {
        guard !isResting, restSegments.isEmpty, dayEnd.map({ date <= $0 }) ?? true else { return }
        update { $0.current.start = date; $0.current.date = date }
    }

    public func setDrivingMinutes(_ minutes: Int) {
        guard minutes >= 0 else { return }
        update { $0.current.drivingMinutes = minutes }
    }

    public func setDayEnd(_ date: Date) {
        guard let start = dayStart, date >= start,
              restSegments.last(where: { $0.end != nil })?.end.map({ date >= $0 }) ?? true else { return }
        update { journal in
            journal.current.end = date
            if isResting {
                journal.current.rests[journal.current.rests.count - 1].start = date
            }
        }
    }

    public func closeShift(at date: Date) {
        guard let start = dayStart, !isResting, date >= start,
              restSegments.last(where: { $0.end != nil })?.end.map({ date >= $0 }) ?? true else { return }
        update { journal in
            journal.current.end = date
            journal.current.isClosed = true
            journal.current.rests.append(RestSegment(start: date))
        }
    }

    public func closeDay() {
        guard let end = dayEnd else { return }
        closeShift(at: end)
    }

    public func reopenDay() {
        // Reopen summary without altering logged period.
    }

    public func deleteEntry(_ type: LogEntryType) {
        // Timeline events cannot be removed once rest has begun; preserve segments.
        guard restSegments.isEmpty || type == .driving else { return }
        update { journal in
            switch type {
            case .dayStart: journal.current.start = nil; journal.current.end = nil
            case .driving: journal.current.drivingMinutes = nil
            case .dayEnd: journal.current.end = nil
            }
            if journal.current.rests.isEmpty { journal.current.isClosed = false }
        }
    }

    public func resetToInitial() {
        update { $0.current = DutyPeriod(date: selectedDate) }
    }
}
