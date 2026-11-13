//
//  DaySummarySheet.swift
//  TachoBook
//

import SwiftUI

/// Figma frame 02 "Day tapped - Day summary sheet (medium)" (708:31844): a read-only summary of one day
/// with the Work and Rest gauges and the Day Times Row as on Home; no country codes (decision 8). A day with a
/// recorded deviation opens full height with its lines and "Go to rule" / "Skip for now" (Flow 3 View History,
/// frame 03, 750:15188; decision 20). Every value comes from the same helpers as Home.
struct DaySummarySheet: View {
    var model: DayLogModel
    var day: Date
    var onClose: () -> Void
    /// Several violations on one day: "Go to rule" opens the Violations list instead (not in Figma, decision 20).
    var onOpenViolations: () -> Void = {}
    @State private var rule: ViolationKey?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let summary = DaySummary(model: model, day: day, now: now)
            VStack(spacing: 0) {
                TitledSheetToolbar(title: "Day summary", subtitle: summary.subtitle,
                                   subtitleIdentifier: "daySummaryDate", onClose: onClose)
                ScrollView {
                    if summary.isEmpty {
                        Text("No records for this day.")
                            .font(.body)
                            .foregroundStyle(Color.tachoTextOnLight)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                            .accessibilityIdentifier("daySummaryEmpty")
                    } else {
                        content(summary)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                if !summary.violations.isEmpty {
                    ruleButtons(summary)
                }
            }
        }
        .environment(\.colorScheme, .light)
        // Frame 03 is full height; a day without a violation keeps the medium sheet (frame 02).
        .presentationDetents(hasViolations ? [.large] : [.medium, .large])
        .sheet(item: $rule) { key in
            ViolationSheet(model: model, key: key, style: .list, onClose: { rule = nil })
        }
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(red: 245/255, green: 245/255, blue: 245/255))
    }

    private func content(_ summary: DaySummary) -> some View {
        VStack(spacing: 32) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { gauges(summary) }
                VStack(spacing: 16) { gauges(summary) }
            }
            .frame(maxWidth: .infinity)
            DayTimesRow(items: summary.times)
            if !summary.violations.isEmpty {
                violationLines(summary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var hasViolations: Bool {
        !model.violations(now: Date()).filter { $0.day == Calendar.current.startOfDay(for: day) }.isEmpty
    }

    /// One red line per violation and its status line: the reminder while the printout is missing, the green
    /// counter once it is done (decision 20 d, e).
    private func violationLines(_ summary: DaySummary) -> some View {
        VStack(spacing: 8) {
            ForEach(summary.violations) { line in
                Text(line.red)
                    .foregroundStyle(TachoTheme.alertRedText)
                    .accessibilityIdentifier("daySummaryRedLine")
                Text(line.status)
                    .foregroundStyle(line.isPrintoutDone ? TachoTheme.successGreenText : Color.tachoTextOnLight)
                    .accessibilityIdentifier("daySummaryStatusLine")
            }
        }
        .font(.body)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
    }

    private func ruleButtons(_ summary: DaySummary) -> some View {
        VStack(spacing: 8) {
            Button {
                if summary.violations.count == 1 {
                    rule = summary.violations[0].id
                } else {
                    onOpenViolations()
                }
            } label: {
                SheetCapsuleLabel(title: "Go to rule", fill: TachoTheme.orangeStrong)
            }
            .buttonStyle(HomeCapsuleButtonStyle())
            .accessibilityIdentifier("goToRuleButton")
            Button("Skip for now", action: onClose)
                .buttonStyle(SheetTextButtonStyle())
                .accessibilityIdentifier("skipForNowButton")
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }

    @ViewBuilder private func gauges(_ summary: DaySummary) -> some View {
        GaugeProgressView(limit: summary.workLimit, value: summary.workValue,
                          progress: summary.workProgress, tint: .tachoOrange,
                          countIcon: .hammer, reducedRestsUsed: summary.reducedRestsUsed)
            .accessibilityIdentifier("daySummaryWork")
        GaugeProgressView(limit: summary.restLimit, value: summary.restValue,
                          progress: summary.restProgress, tint: .tachoBlue,
                          countIcon: .bed, reducedRestsUsed: summary.reducedRestsUsed)
            .accessibilityIdentifier("daySummaryRest")
    }
}

/// The values of one day, derived from stored records with Home's helpers (past-day Work and Rest Taken
/// cards, Day summary card) so the sheet and Home always agree.
struct DaySummary {
    struct Time: Identifiable {
        var symbol: String
        var label: String
        var value: String
        /// The country under a start or close time, as on Home ("🇭🇺 H", "?").
        var detail: ShiftPlaceLine? = nil
        var identifier: String
        var id: String { identifier }
    }

    var subtitle: String
    var isEmpty: Bool
    var workLimit: String
    var workValue: String
    var workProgress: Double
    var restLimit: String
    var restValue: String
    var restProgress: Double
    var reducedRestsUsed: Int?
    var times: [Time]
    var violations: [ViolationLine]

    /// The lines of one recorded deviation on this day.
    struct ViolationLine: Identifiable {
        var id: ViolationKey
        var red: String
        var status: String
        var isPrintoutDone: Bool
    }

    init(model: DayLogModel, day: Date, now: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: day)
        let record = model.historyRecord(on: day, calendar: calendar)
        // "20 Apr 2026 · 1 violation" as in Figma: Home's date label with the year, then the count (decision 20 c).
        let date = "\(HomeTimeline.dateLabel(day, calendar: calendar)) \(calendar.component(.year, from: day))"
        isEmpty = record == nil
        let found = model.violations(now: now, calendar: calendar).filter { $0.day == day }.reversed()
        violations = found.map { violation in
            let printedAt = model.printout(for: violation.key)
            let status = model.carryStatus(of: violation, now: now, calendar: calendar)
            return ViolationLine(
                id: violation.key, red: ViolationCopy.redLine(violation),
                status: printedAt.map { ViolationCopy.printoutLine(printedAt: $0, status: status, calendar: calendar) }
                    ?? ViolationCopy.reminder,
                isPrintoutDone: printedAt != nil)
        }
        subtitle = isEmpty && violations.isEmpty ? date : "\(date) · \(ViolationCopy.violationCount(violations.count))"

        // Work: start to close, or to now while the shift is open (as the Home Work card).
        let isOpen = record?.id == model.dutyID && model.isShiftOpen
        let elapsed = record?.start.flatMap { start in
            (record?.end ?? (isOpen ? now : nil)).map { HomeTimeline.elapsedSeconds(from: start, to: $0) }
        }
        // A running shift keeps the 15 h scale, as on Home today; a finished one shows 13 h or 15 h.
        workLimit = "\(isOpen ? HomeTimeline.dutyMarkerHours.second : HomeTimeline.pastDutyLimitHours(seconds: elapsed))h"
        workValue = elapsed.map { HomeTimeline.clockDuration(seconds: $0) } ?? "?"
        workProgress = Double(elapsed ?? 0) / (Double(HomeTimeline.dutyMarkerHours.second) * 3600)

        // Rest taken after the shift (the past-day Rest Taken card).
        let rest = model.restTaken(after: record, now: now)
        restLimit = HomeTimeline.restTakenLabel(rest)
        restValue = rest.map { HomeTimeline.clockDuration(seconds: $0.seconds) } ?? "?"
        restProgress = HomeTimeline.restTakenFill(seconds: rest?.seconds)

        // Reductions up to this day, the rest after this day's own shift included (Serhii, 25.10.2026).
        reducedRestsUsed = model.historyReducedRests(onDay: day, now: now, calendar: calendar)

        times = [
            Time(symbol: "play.circle", label: "Day started",
                 value: record?.start.map { HomeTimeline.clockLabel($0, relativeTo: day, calendar: calendar) } ?? "?",
                 detail: ShiftPlaceLine(place: record?.startPlace, recordedAt: record?.start),
                 identifier: "daySummaryStarted"),
            Time(symbol: "steeringwheel", label: "Driving",
                 value: HomeTimeline.drivingLabel(minutes: record?.drivingMinutes),
                 identifier: "daySummaryDriving"),
            Time(symbol: "stop.circle", label: "Day closed",
                 value: record?.end.map { HomeTimeline.clockLabel($0, relativeTo: day, calendar: calendar) } ?? "?",
                 detail: ShiftPlaceLine(place: record?.endPlace, recordedAt: record?.end),
                 identifier: "daySummaryClosed"),
        ]
    }
}

/// Figma "Day Times Row": three columns separated by faded rules; read-only.
private struct DayTimesRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var items: [DaySummary.Time]

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        // Top-aligned like Home's summary, so Driving (no country line) starts level with the others.
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        layout {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 && !stacked {
                    FadedRule(axis: .vertical).frame(width: 1, height: 44)
                }
                HomeValueColumn(symbol: item.symbol, label: item.label, value: item.value, detail: item.detail)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(item.identifier)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
