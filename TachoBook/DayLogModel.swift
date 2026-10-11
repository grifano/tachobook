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
    public var selectedDate: Date
    public var dayStart: Date?
    public var drivingMinutes: Int?
    public var dayEnd: Date?
    public var isDayClosed: Bool = false

    public init(date: Date = DayLogModel.defaultReferenceDate()) {
        self.selectedDate = date
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
        let diff = Calendar.current.dateComponents([.minute], from: start, to: end).minute ?? 0
        return max(0, diff)
    }

    public var workingFraction: Double {
        // Daily working limit max in EU tachograph regulations is typically 15h (900m)
        let totalLimit: Double = 15 * 60
        guard let current = workingMinutes else {
            return dayStart != nil ? (10.0 / totalLimit) : 0.0
        }
        return min(1.0, Double(current) / totalLimit)
    }

    public var workingTimeString: String {
        if let minutes = workingMinutes {
            let h = minutes / 60
            let m = minutes % 60
            return String(format: "%d:%02d", h, m)
        } else if dayStart != nil {
            return "0:10"
        } else {
            return "0:00"
        }
    }

    public var restTimeString: String {
        if isDayClosed || canCloseDay {
            return "0:20"
        } else {
            return "0:00"
        }
    }

    public var restFraction: Double {
        if isDayClosed || canCloseDay {
            return 0.15
        } else {
            return 0.0
        }
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
        dayStart = date
    }

    public func setDrivingMinutes(_ minutes: Int) {
        drivingMinutes = minutes
    }

    public func setDayEnd(_ date: Date) {
        dayEnd = date
    }

    public func closeDay() {
        guard canCloseDay else { return }
        isDayClosed = true
    }

    public func reopenDay() {
        // Reopen summary without altering logged day
    }

    public func deleteEntry(_ type: LogEntryType) {
        switch type {
        case .dayStart:
            dayStart = nil
        case .driving:
            drivingMinutes = nil
        case .dayEnd:
            dayEnd = nil
        }
        if !canCloseDay {
            isDayClosed = false
        }
    }

    public func resetToInitial() {
        dayStart = nil
        drivingMinutes = nil
        dayEnd = nil
        isDayClosed = false
    }
}
