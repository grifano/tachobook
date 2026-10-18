//
//  HomeTimeline.swift
//  TachoBook
//

import Foundation

/// Pure Home calculations from persisted timestamps and the current time.
/// Hours are elapsed seconds (R-T01), never calendar-day addition.
public enum HomeTimeline {
    /// R-D05 duty markers from the start entered in the Shift start sheet.
    public static let dutyMarkerHours = (first: 13, second: 15)

    /// Red remaining time below the 15 h marker. Not defined in Figma or the
    /// specification; awaiting Serhii's confirmation.
    public static let dutyWarningThreshold: TimeInterval = 3600

    public static func adding(hours: Int, to date: Date) -> Date {
        date.addingTimeInterval(TimeInterval(hours) * 3600)
    }

    public static func elapsedSeconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start)))
    }

    /// Whole hours and minutes, hours may exceed 24: 27:19.
    public static func clockDuration(seconds: Int) -> String {
        let seconds = max(0, seconds)
        return String(format: "%02d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }

    /// Time left, rounded up to the minute so it complements the elapsed time
    /// (00:01 elapsed of 9 h shows 08:59 left).
    public static func remainingDuration(seconds: Int) -> String {
        clockDuration(seconds: (max(0, seconds) + 59) / 60 * 60)
    }

    public static func dutyMarkers(shiftStart: Date) -> (first: Date, second: Date) {
        (adding(hours: dutyMarkerHours.first, to: shiftStart), adding(hours: dutyMarkerHours.second, to: shiftStart))
    }

    public static func restMilestones(restStart: Date, kind: RestKind) -> (first: Date, second: Date) {
        (adding(hours: kind.milestoneHours.first, to: restStart), adding(hours: kind.milestoneHours.second, to: restStart))
    }

    /// Seconds left until the 15 h marker at `instant` (now, or the close time of a frozen shift).
    public static func dutyRemainingSeconds(shiftStart: Date, at instant: Date) -> Int {
        elapsedSeconds(from: instant, to: dutyMarkers(shiftStart: shiftStart).second)
    }

    public static func isDutyWarning(shiftStart: Date, at instant: Date) -> Bool {
        TimeInterval(dutyRemainingSeconds(shiftStart: shiftStart, at: instant)) <= dutyWarningThreshold
    }

    /// Start of day countdown; nil once the milestone is reached.
    public static func availabilityCountdown(restStart: Date, kind: RestKind, now: Date) -> String? {
        let available = adding(hours: kind.requiredHours, to: restStart)
        guard now < available else { return nil }
        return remainingDuration(seconds: elapsedSeconds(from: now, to: available))
    }

    /// "08:34", with a weekday suffix ("08:34 Su") when the day differs from `now`.
    public static func clockLabel(_ date: Date, relativeTo now: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: date)
        guard !calendar.isDate(date, inSameDayAs: now) else { return time }
        formatter.dateFormat = "EEEEEE"
        return "\(time) \(formatter.string(from: date))"
    }

    /// "Today" when on the same day as `now`, otherwise "17 Oct".
    public static func dayLabel(_ date: Date, relativeTo now: Date, calendar: Calendar = .current) -> String {
        calendar.isDate(date, inSameDayAs: now) ? "Today" : dateLabel(date, calendar: calendar)
    }

    /// "17 Oct".
    public static func dateLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    /// "09h52m"; "?" while the driver has not entered driving time.
    public static func drivingLabel(minutes: Int?) -> String {
        guard let minutes else { return "?" }
        return String(format: "%02dh%02dm", minutes / 60, minutes % 60)
    }
}
