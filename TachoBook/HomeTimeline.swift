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

    /// Seconds left until the applicable duty marker (15 h, or 13 h at 3 of 3) at `instant`
    /// (now, or the close time of a frozen shift).
    public static func dutyRemainingSeconds(shiftStart: Date, at instant: Date,
                                            limitHours: Int = dutyMarkerHours.second) -> Int {
        elapsedSeconds(from: instant, to: adding(hours: limitHours, to: shiftStart))
    }

    public static func isDutyWarning(shiftStart: Date, at instant: Date, limitHours: Int = dutyMarkerHours.second) -> Bool {
        TimeInterval(dutyRemainingSeconds(shiftStart: shiftStart, at: instant, limitHours: limitHours)) <= dutyWarningThreshold
    }

    // MARK: - 13 h / 11 h at 3 of 3 (R-D05; owner decisions 4–5, 30.10.2026)

    /// The Work gauge label and scale: 13 h when only an 11 h rest is possible, otherwise 15 h
    /// (an unknown count keeps 15 h, as before).
    public static func dutyGaugeHours(_ limits: DutyLimitAvailability) -> Int {
        limits == .thirteenHoursOnly ? dutyMarkerHours.first : dutyMarkerHours.second
    }

    /// The "…h limit end" rows on the Work card: only 13 h at 3 of 3 without a confirmed split.
    public static func shownDutyMarkerHours(_ limits: DutyLimitAvailability) -> [Int] {
        limits == .thirteenHoursOnly ? [dutyMarkerHours.first] : [dutyMarkerHours.first, dutyMarkerHours.second]
    }

    /// The daily Rest gauge label and scale: 11 h at 3 of 3 without a confirmed split, otherwise 9 h.
    public static func dailyRestRequiredHours(_ limits: DutyLimitAvailability) -> Int {
        let hours = RestKind.daily.milestoneHours
        return limits == .thirteenHoursOnly ? hours.second : hours.first
    }

    /// The "After …h rest" rows of a daily rest (Rest card, next-rest card): only 11 h at 3 of 3 without a split.
    public static func shownDailyRestMilestoneHours(_ limits: DutyLimitAvailability) -> [Int] {
        let hours = RestKind.daily.milestoneHours
        return limits == .thirteenHoursOnly ? [hours.second] : [hours.first, hours.second]
    }

    /// A daily rest that continues to 11 h is shown as a weekly rest (R-W01: a daily rest can
    /// continue into a weekly one; the type stays provisional). Display only: the stored kind and
    /// the Start of day milestone are unchanged.
    public static let weeklyDisplayAfter: TimeInterval = 11 * 3600

    public static func displayedRestKind(stored: RestKind, restStart: Date, now: Date) -> RestKind {
        guard stored == .daily else { return stored }
        return now.timeIntervalSince(restStart) >= weeklyDisplayAfter ? .weekly : .daily
    }

    /// Fill of the past-day Rest Taken arc: rest taken against the 9 h daily scale, clamped to 0...1.
    /// The scale is only a fill reference, not a rest classification. nil (no record) stays empty.
    public static func restTakenFill(seconds: Int?) -> Double {
        guard let seconds else { return 0 }
        let scale = Double(RestKind.daily.requiredHours) * 3600
        return min(max(Double(seconds) / scale, 0), 1)
    }

    /// Gauge label of a finished shift on a past day (Serhii, 25.10.2026): 13 h up to 13 h of duty, 15 h beyond.
    /// nil duty (no shift) keeps the 15 h scale.
    public static func pastDutyLimitHours(seconds: Int?) -> Int {
        guard let seconds else { return dutyMarkerHours.second }
        return TimeInterval(seconds) > TimeInterval(dutyMarkerHours.first) * 3600 ? dutyMarkerHours.second : dutyMarkerHours.first
    }

    /// The rest norm a finished rest reached, by its length (Serhii, 25.10.2026): under 11 h → 9 h, 11 h up to
    /// 24 h → 11 h, 24 h up to 45 h → 24 h, 45 h or more → 45 h.
    public static func restNormHours(seconds: Int) -> Int {
        switch seconds {
        case (45 * 3600)...: 45
        case (24 * 3600)...: 24
        case (11 * 3600)...: 11
        default: 9
        }
    }

    /// Label above a past day's rest: "So far" while it runs, its norm once it ended, "Taken" without a rest.
    public static func restTakenLabel(_ rest: RestTaken?) -> String {
        guard let rest else { return "Taken" }
        guard rest.end != nil else { return "So far" }
        return "\(restNormHours(seconds: rest.seconds))h"
    }

    /// Start of day countdown; nil once the milestone is reached.
    public static func availabilityCountdown(restStart: Date, kind: RestKind, now: Date) -> String? {
        let available = adding(hours: kind.requiredHours, to: restStart)
        guard now < available else { return nil }
        return remainingDuration(seconds: elapsedSeconds(from: now, to: available))
    }

    // MARK: - Start of day at 3 of 3 (R-D05, section 8; owner decision 01.11.2026)

    /// The Start of day button during a rest.
    public enum StartOfDayAvailability: Equatable {
        /// Before the earliest allowed start (9 h daily, 45 h weekly): dimmed and disabled, counting down to the full rest.
        case waiting(countdown: String)
        /// 9 h up to 11 h of a daily rest at 3 of 3 without a confirmed split: dimmed but tappable, counting down
        /// to 11 h. A tap warns first that starting now breaks the rest rules; it never blocks.
        case earlyStart(countdown: String, fullRestEnd: Date)
        /// The required rest is complete, or there is no rest: orange, no warning.
        case available

        public var countdown: String? {
            switch self {
            case .waiting(let countdown), .earlyStart(let countdown, _): countdown
            case .available: nil
            }
        }

        public var isEnabled: Bool {
            if case .waiting = self { false } else { true }
        }
    }

    /// Start of day for a rest that began at `restStart`. A daily rest needs 11 h at 3 of 3 without a confirmed
    /// split (the same rule as the Rest gauge), but from 9 h a start is allowed with a warning; every other case
    /// becomes available at the rest's own milestone, as before.
    public static func startOfDayAvailability(restStart: Date?, kind: RestKind, limits: DutyLimitAvailability,
                                              now: Date) -> StartOfDayAvailability {
        guard let restStart else { return .available }
        let required = kind == .daily ? dailyRestRequiredHours(limits) : kind.requiredHours
        let fullRestEnd = adding(hours: required, to: restStart)
        guard now < fullRestEnd else { return .available }
        let countdown = remainingDuration(seconds: elapsedSeconds(from: now, to: fullRestEnd))
        return now < adding(hours: kind.requiredHours, to: restStart)
            ? .waiting(countdown: countdown)
            : .earlyStart(countdown: countdown, fullRestEnd: fullRestEnd)
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

    /// Header subtitle: the date only, "18 October 2026".
    public static func headerDate(_ now: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        return formatter.string(from: now)
    }

    /// "Sat 17" in the device locale.
    public static func weekdayAndDay(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEd")
        return formatter.string(from: date)
    }

    /// "Sat 17, 08:34": weekday, day and time in the device locale (24 h or AM/PM as the device uses).
    public static func dayAndTime(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(weekdayAndDay(date, calendar: calendar)), \(formatter.string(from: date))"
    }

    public struct WeekStripDay: Equatable {
        public var date: Date
        /// Days from today: negative for earlier days.
        public var offset: Int
        public var isToday: Bool { offset == 0 }
    }

    /// Number of dates in the header strip.
    public static let stripLength = 5

    /// The strip never re-centres: `DayHistory.maxDaysBack` days before today, today, and the days
    /// after today that fill the remaining slots (3 back, today, tomorrow). It follows the device
    /// calendar, so today moves at local midnight.
    public static func dateStrip(today now: Date, daysBack: Int = DayHistory.maxDaysBack,
                                 length: Int = stripLength, calendar: Calendar = .current) -> [WeekStripDay] {
        let today = calendar.startOfDay(for: now)
        let first = -min(max(0, daysBack), length - 1)
        return (first..<(first + length)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map { WeekStripDay(date: $0, offset: offset) }
        }
    }

    /// "09h52m"; "?" while the driver has not entered driving time.
    public static func drivingLabel(minutes: Int?) -> String {
        guard let minutes else { return "?" }
        return String(format: "%02dh%02dm", minutes / 60, minutes % 60)
    }
}
