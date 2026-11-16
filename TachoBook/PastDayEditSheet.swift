//
//  PastDayEditSheet.swift
//  TachoBook
//

import SwiftUI

/// The edit sheet for one value of an earlier day's shift: Day started, Driving or Day closed. One place for Home's
/// earlier days (MVP-07) and the History Day summary (decision 8, 16.11.2026), so both use the same defaults, the same
/// checks and reason lines (R-E01, F4), the decision-14 red line and the country row of an edit (never located).
/// The current record in its rest is edited through Home's own commands (`setStart(_:onDay:)` routes it); the open
/// shift is not a past-day record and is never edited here.
struct PastDayEditSheet: View {
    enum Field: String, Identifiable {
        case start
        case driving
        case end

        var id: String { rawValue }
    }

    var model: DayLogModel
    var day: Date
    var field: Field
    /// After the value was saved.
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        let now = Date()
        let record = model.dayRecord(on: day)
        switch field {
        case .start:
            TimeEntrySheet(kind: .shiftStart, initialDate: record?.start ?? DayHistory.combine(day: day, timeOf: now),
                           range: DayHistory.range(of: day),
                           check: { model.checkSetStart($0, onDay: day, now: Date()) },
                           warning: overLimitLine { $0.setStart($1, onDay: day, now: Date()) },
                           country: editCountry(record?.startPlace),
                           onConfirm: { model.setStart($0, onDay: day, now: Date(), place: $1); onSave() },
                           onCancel: onCancel)
        case .end:
            let floor = record?.start ?? day
            TimeEntrySheet(kind: .restStart, initialDate: record?.end ?? DayHistory.combine(day: day, timeOf: now),
                           range: floor...max(floor, now),
                           check: { model.checkSetEnd($0, onDay: day, now: Date()) },
                           warning: overLimitLine { $0.setEnd($1, onDay: day, now: Date()) },
                           country: editCountry(record?.endPlace),
                           onConfirm: { model.setEnd($0, onDay: day, now: Date(), place: $1); onSave() },
                           onCancel: onCancel)
        case .driving:
            DailyDrivingSheet(initialMinutes: record?.drivingMinutes,
                              onConfirm: { model.setDriving(minutes: $0, onDay: day); onSave() },
                              onCancel: onCancel)
        }
    }

    /// Editing a start or close: the stored country, changeable; older records may stay without one.
    private func editCountry(_ place: ShiftPlace?) -> CountryEntry {
        CountryEntry(initial: .editing(place), recents: model.recentCountries(), locator: nil, required: false)
    }

    /// Decision 14 for an earlier day: the shift shown for that day after the change.
    private func overLimitLine(_ change: @escaping (DayLogModel, Date) -> Void) -> (Date) -> String? {
        { date in
            DayLogModel.overLimitLine(model.dutyViolation(previewing: { change($0, date) },
                                                          periodID: { $0.historyRecord(on: day)?.id }, now: Date()))
        }
    }
}

extension DayLogModel {
    /// Whether the History Day summary can edit `day`: it has a record and that record is not the open shift (as on
    /// Home, where the running shift has no edit fields). An empty day stays read-only (decision 9).
    public func canEditHistoryDay(_ day: Date, calendar: Calendar = .current) -> Bool {
        guard storageError == nil, let record = historyRecord(on: day, calendar: calendar) else { return false }
        return !(record.id == dutyID && isShiftOpen)
    }

    /// The earliest deviation in the records now that `before` did not contain: the one an edit just created.
    public func firstNewViolation(since before: Set<ViolationKey>, now: Date,
                                  calendar: Calendar = .current) -> Violation? {
        violations(now: now, calendar: calendar).filter { !before.contains($0.key) }.min { $0.began < $1.began }
    }
}
