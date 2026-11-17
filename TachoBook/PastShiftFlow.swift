//
//  PastShiftFlow.swift
//  TachoBook
//

import SwiftUI

/// Asks for the past-shift flow. `day` preselects the day of the shift start; nil starts at now.
struct PastShiftRequest: Identifiable, Equatable {
    let id = UUID()
    var day: Date?
}

extension View {
    /// The one entry point for adding a past shift (owner decisions 5 and 6, 16.11.2026), independent of the screen
    /// that opens it: History opens it with now, Home (next Task) with a past day.
    func pastShiftFlow(_ request: Binding<PastShiftRequest?>, model: DayLogModel) -> some View {
        modifier(PastShiftFlow(request: request, model: model))
    }
}

/// The normal shift flow for an earlier day: Shift start → Rest start (the close) → Driving time, in the same sheets as
/// on Home. The day is picked in the start sheet. Nothing is saved before the last step; a collision with a saved
/// shift or the open shift asks whether to replace it. A deviation in the saved shift opens its violation sheet.
struct PastShiftFlow: ViewModifier {
    enum Step: Identifiable, Equatable {
        case start
        case end
        case driving
        case violation(ViolationKey)

        var id: String {
            switch self {
            case .start: "start"
            case .end: "end"
            case .driving: "driving"
            case .violation(let key): "violation-\(key.storageID)"
            }
        }
    }

    @Binding var request: PastShiftRequest?
    var model: DayLogModel

    @State private var step: Step?
    @State private var draft = PastShiftDraft(now: Date())
    /// The records the entry collides with, while the replace alert is up.
    @State private var conflicts: [PastShiftConflict] = []
    /// Where Replace leads.
    @State private var afterReplace: Step?

    func body(content: Content) -> some View {
        content
            .onChange(of: request, initial: true) { _, new in
                guard let new else { return }
                draft = PastShiftDraft(day: new.day, now: Date())
                conflicts = []
                step = .start
            }
            .onChange(of: step) { _, new in
                if new == nil { request = nil }
            }
            .sheet(item: $step) { step in
                sheet(step)
                    .alert(PastShiftCopy.replaceTitle, isPresented: replaceAlertShown) {
                        Button(PastShiftCopy.replaceButton, role: .destructive) { replace() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(PastShiftCopy.replaceMessage(conflicts))
                    }
            }
    }

    @ViewBuilder
    private func sheet(_ step: Step) -> some View {
        let now = Date()
        switch step {
        case .start:
            TimeEntrySheet(kind: .shiftStart, initialDate: draft.start, range: Date.distantPast...now,
                           check: { model.checkPastShiftStart($0, now: Date()) },
                           country: country(lastPlace: model.lastPlace),
                           onConfirm: { date, place in
                               draft.start = date
                               draft.startPlace = place
                               proceed(to: .end, conflicts: model.pastShiftConflicts(start: date, end: nil, now: Date()))
                           },
                           onCancel: cancel)
        case .end:
            let start = draft.start
            TimeEntrySheet(kind: .restStart,
                           initialDate: min(max(DayHistory.combine(day: start, timeOf: now), start), now),
                           range: start...max(start, now),
                           check: { model.checkPastShiftEnd($0, start: start, now: Date()) },
                           warning: { [draft] in model.pastShiftOverLimitLine(draft, end: $0, now: Date()) },
                           country: country(lastPlace: draft.startPlace ?? model.lastPlace),
                           onConfirm: { date, place in
                               draft.end = date
                               draft.endPlace = place
                               proceed(to: .driving,
                                       conflicts: model.pastShiftConflicts(start: start, end: date, now: Date()))
                           },
                           onCancel: cancel)
        case .driving:
            DailyDrivingSheet(initialMinutes: nil, onConfirm: save, onCancel: cancel)
        case .violation(let key):
            ViolationSheet(model: model, key: key, style: .list, onClose: cancel)
        }
    }

    /// The normal flow's country row. A past date is never filled from the current location: the most recent country.
    private func country(lastPlace: ShiftPlace?) -> CountryEntry {
        CountryEntry(initial: .newEvent(lastPlace: lastPlace), recents: model.recentCountries(), locator: nil,
                     required: true)
    }

    private var replaceAlertShown: Binding<Bool> {
        Binding(get: { !conflicts.isEmpty }, set: { if !$0 { conflicts = [] } })
    }

    /// Next step, or the replace alert first for collisions the driver has not agreed to replace.
    private func proceed(to next: Step, conflicts found: [PastShiftConflict]) {
        let open = found.filter { !draft.replacing.contains($0.id) }
        guard open.isEmpty else {
            afterReplace = next
            conflicts = open
            return
        }
        step = next
    }

    private func replace() {
        draft.replacing.formUnion(conflicts.map(\.id))
        conflicts = []
        step = afterReplace
    }

    private func save(drivingMinutes: Int) {
        let now = Date()
        guard model.savePastShift(draft, drivingMinutes: drivingMinutes, now: now) else { return cancel() }
        // A deviation in the saved shift: the violation sheet, so the printout and its 56 days can be marked.
        step = model.pastShiftViolation(id: draft.id, now: now).map { .violation($0.key) }
    }

    private func cancel() {
        step = nil
    }
}
