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
    private(set) var state: ShiftJournal
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
    public var restKind: RestKind { restSegments.last?.kind ?? .daily }
    public var currentRestStart: Date? { isResting ? restSegments.last?.start : nil }

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
        if args.contains("-homeFlowUITest") {
            let url = URL.applicationSupportDirectory.appending(path: "TachoBook/home-flow-ui/shifts.store")
            if args.contains("-resetHomeFlowTest") {
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            }
            let model = DayLogModel(storageURL: url)
            if args.contains("-seedReadyWeeklyRest") {
                let restStart = Date().addingTimeInterval(-46 * 3600)
                model.seedWeeklyRestIfEmpty(shiftStart: restStart.addingTimeInterval(-3 * 3600),
                                            restStart: restStart, drivingMinutes: 128)
            } else if args.contains("-seedLongShift"), model.isEmpty {
                // A shift from three days ago 20:10 to just after midnight today: it covers yesterday.
                let calendar = Calendar.current
                let midnight = calendar.startOfDay(for: Date())
                if let start = calendar.date(byAdding: .day, value: -3, to: midnight)?.addingTimeInterval(20 * 3600 + 600) {
                    model.seedArchivedShiftIfEmpty(start: start, end: midnight.addingTimeInterval(60))
                }
            } else if args.contains("-seedNearDutyLimit"), model.isEmpty {
                model.setDayStart(Date().addingTimeInterval(-(14 * 3600 + 45 * 60)))
            } else if let index = args.firstIndex(of: "-seedReducedRests"), index + 1 < args.count,
                      let used = Int(args[index + 1]), model.isEmpty {
                // Weekly rest, `used` reduced rests, then the current rest: daily (1 min) or weekly card (12 h).
                // `-seedOpenShiftMinutes M`: instead, a shift still open M minutes after its start.
                let restElapsed: TimeInterval = args.contains("-seedWeeklyCard") ? 12 * 3600 : 60
                let open = args.firstIndex(of: "-seedOpenShiftMinutes").flatMap { $0 + 1 < args.count ? Int(args[$0 + 1]) : nil }
                model.seedReducedRestsIfEmpty(used: used, restElapsed: restElapsed, now: Date(),
                                              openShiftElapsed: open.map { TimeInterval($0) * 60 })
            } else if args.contains("-seedDailyRestNearEleven"), model.isEmpty {
                // A daily rest 20 s short of 11 h, to watch it switch to the weekly card.
                let now = Date()
                model.setDayStart(now.addingTimeInterval(-24 * 3600))
                model.closeShift(at: now.addingTimeInterval(-(11 * 3600 - 20)))
            }
            return model
        }
        #endif
        let model = DayLogModel(storageURL: defaultStorageURL, legacyURL: legacyStorageURL)
        #if DEBUG
        if args.contains("-seedHomeFlow") { model.seedFigmaSampleIfEmpty() }
        #endif
        return model
    }

    #if DEBUG
    /// Figma frame 01 sample: shift 17.10.2026 05:40–08:34, driving 02:08, then
    /// weekly rest from 08:34 in device local time. Never replaces stored data.
    public func seedFigmaSampleIfEmpty(calendar: Calendar = .current) {
        func date(_ hour: Int, _ minute: Int) -> Date? {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: hour, minute: minute))
        }
        guard let start = date(5, 40), let restStart = date(8, 34) else { return }
        seedWeeklyRestIfEmpty(shiftStart: start, restStart: restStart, drivingMinutes: 128)
    }

    /// An archived (past) shift with an empty current record, for UI tests of overlap and cover cases.
    public func seedArchivedShiftIfEmpty(start: Date, end: Date) {
        guard isEmpty, start <= end else { return }
        update { $0.history = [DutyPeriod(date: start, start: start, end: end, isClosed: true)] }
    }

    /// Records for the Rest Count row: a shift and a 46 h weekly rest, then `used` days of 12 h duty with a
    /// 10 h (reduced) rest, then the current shift closed `restElapsed` before `now` — or, with
    /// `openShiftElapsed`, still open and started that long before `now`. Never replaces stored data.
    public func seedReducedRestsIfEmpty(used: Int, restElapsed: TimeInterval, now: Date,
                                        openShiftElapsed: TimeInterval? = nil) {
        guard isEmpty, used >= 0 else { return }
        let hour: TimeInterval = 3600
        let restStart = now.addingTimeInterval(-restElapsed)
        let currentStart = openShiftElapsed.map { now.addingTimeInterval(-$0) } ?? restStart.addingTimeInterval(-3 * hour)
        var periods: [DutyPeriod] = []
        var nextStart = currentStart
        func prepend(start: Date, duty: TimeInterval, kind: RestKind) {
            let end = start.addingTimeInterval(duty)
            periods.insert(DutyPeriod(date: start, start: start, drivingMinutes: 480, end: end, isClosed: true,
                                      rests: [RestSegment(start: end, end: nextStart, dailyRestConfirmed: true, kind: kind)]),
                           at: 0)
            nextStart = start
        }
        for _ in 0..<used { prepend(start: nextStart.addingTimeInterval(-22 * hour), duty: 12 * hour, kind: .daily) }
        prepend(start: nextStart.addingTimeInterval(-54 * hour), duty: 8 * hour, kind: .weekly)
        update { journal in
            journal.history = periods
            journal.current = openShiftElapsed == nil
                ? DutyPeriod(date: currentStart, start: currentStart, drivingMinutes: 128, end: restStart,
                             isClosed: true, rests: [RestSegment(start: restStart, kind: .daily)])
                : DutyPeriod(date: currentStart, start: currentStart, drivingMinutes: 128)
        }
    }

    public func seedWeeklyRestIfEmpty(shiftStart: Date, restStart: Date, drivingMinutes: Int) {
        guard isEmpty, shiftStart <= restStart else { return }
        update { journal in
            journal.current = DutyPeriod(date: shiftStart, start: shiftStart, drivingMinutes: drivingMinutes,
                                         end: restStart, isClosed: true,
                                         rests: [RestSegment(start: restStart, kind: .weekly)])
        }
    }
    #endif

    /// No current or archived record exists yet.
    public var isEmpty: Bool {
        dayStart == nil && dayEnd == nil && drivingMinutes == nil && restSegments.isEmpty && archivedPeriods.isEmpty
    }

    public static var defaultStorageURL: URL {
        URL.applicationSupportDirectory.appending(path: "TachoBook/shifts-v1.store")
    }

    public static var legacyStorageURL: URL {
        URL.applicationSupportDirectory.appending(path: "TachoBook/shift-journal-v1.json")
    }

    func update(_ change: (inout ShiftJournal) -> Void) {
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
              date.timeIntervalSince(rest.start) >= Double(restKind.requiredHours) * 3600 else { return }
        update { journal in
            journal.current.rests[journal.current.rests.count - 1].end = date
            journal.current.rests[journal.current.rests.count - 1].dailyRestConfirmed = true
            journal.history.append(journal.current)
            journal.history.sortChronologically()
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
            // Every rest started by closing a shift in the app is daily.
            journal.current.rests.append(RestSegment(start: date, kind: .daily))
        }
    }

    // MARK: - Home commands with validation (R-E01: no end before start, no overlap)

    /// The end of the previous archived period's rest, which the current start must not precede.
    private var previousRest: RestSegment? { archivedPeriods.last?.rests.last }

    private var lastClosedRestEnd: Date? { restSegments.last(where: { $0.end != nil })?.end }

    /// Start of day: available once the current rest reached its required milestone.
    public func canStartShift(at date: Date, now: Date) -> Bool { checkStartShift(at: date, now: now) == nil }

    /// nil when valid, else why not. `.other` has no approved copy yet.
    public func checkStartShift(at date: Date, now: Date) -> TimeEntryIssue? {
        guard date <= now else { return .future }
        if let blocker = archivedPeriods.filter({ $0.end.map { date < $0 } ?? false }).max(by: { $0.end! < $1.end! }),
           let end = blocker.end {
            return .overlap(from: blocker.start ?? end, to: end)
        }
        if isResting, let rest = restSegments.last {
            return date.timeIntervalSince(rest.start) >= Double(restKind.requiredHours) * 3600 ? nil : .other
        }
        guard dayStart == nil else { return .other }
        return previousRest?.end.map { date >= $0 } ?? true ? nil : .other
    }

    public func startShift(at date: Date, now: Date) {
        guard canStartShift(at: date, now: now) else { return }
        if isResting {
            startNewShift(at: date, dailyRestConfirmed: true)
        } else {
            setDayStart(date)
        }
    }

    /// End of day: closes the open shift and starts a daily rest at `date`.
    public func canCloseShift(at date: Date, now: Date) -> Bool { checkCloseShift(at: date, now: now) == nil }

    public func checkCloseShift(at date: Date, now: Date) -> TimeEntryIssue? {
        guard isShiftOpen, let start = dayStart else { return .other }
        if date > now { return .future }
        if date < start { return .endBeforeStart(start: start) }
        return (lastClosedRestEnd.map { date >= $0 } ?? true) ? nil : .other
    }

    public func closeShift(at date: Date, now: Date) {
        guard canCloseShift(at: date, now: now) else { return }
        closeShift(at: date)
    }

    /// Editing Day started keeps the previous rest linked to it when they share the instant.
    public func canEditDayStart(_ date: Date, now: Date) -> Bool { checkEditDayStart(date, now: now) == nil }

    public func checkEditDayStart(_ date: Date, now: Date) -> TimeEntryIssue? {
        guard let current = dayStart else { return .other }
        if date > now { return .future }
        if let end = dayEnd, date > end { return .endBeforeStart(start: date) }
        if let blocker = overlapBlocker(start: date, end: dayEnd ?? date, excluding: dutyID, now: now) {
            return .overlap(from: blocker.from, to: blocker.to)
        }
        if let firstRest = restSegments.first, date > firstRest.start { return .other }
        if let previous = archivedPeriods.last, let rest = previous.rests.last {
            let tooEarly = rest.end == current ? date < rest.start : (rest.end.map { date < $0 } ?? false)
            if tooEarly { return .overlap(from: previous.start ?? rest.start, to: previous.end ?? rest.start) }
        }
        return nil
    }

    public func editDayStart(_ date: Date, now: Date) {
        guard canEditDayStart(date, now: now), let current = dayStart else { return }
        let linked = previousRest?.end == current
        update { journal in
            journal.current.start = date
            journal.current.date = date
            if linked, let last = journal.history.indices.last, !journal.history[last].rests.isEmpty {
                journal.history[last].rests[journal.history[last].rests.count - 1].end = date
            }
        }
    }

    /// Editing Day closed moves the running rest start with it.
    public func canEditDayEnd(_ date: Date, now: Date) -> Bool { checkEditDayEnd(date, now: now) == nil }

    public func checkEditDayEnd(_ date: Date, now: Date) -> TimeEntryIssue? {
        guard dayEnd != nil, let start = dayStart else { return .other }
        if date > now { return .future }
        if date < start { return .endBeforeStart(start: start) }
        if let rest = lastClosedRestEnd, date < rest { return .other }
        if let blocker = overlapBlocker(start: start, end: date, excluding: dutyID, now: now) {
            return .overlap(from: blocker.from, to: blocker.to)
        }
        return nil
    }

    public func editDayEnd(_ date: Date, now: Date) {
        guard canEditDayEnd(date, now: now) else { return }
        setDayEnd(date)
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
