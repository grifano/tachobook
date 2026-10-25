//
//  DaySummarySheet.swift
//  TachoBook
//

import SwiftUI

/// Figma frame 02 "Day tapped - Day summary sheet (medium)" (708:31844): a read-only summary of one day
/// with the Work and Rest gauges and the Day Times Row as on Home. No violation text yet (decision 5) and
/// no country codes (decision 8). Every value comes from the same helpers as Home.
struct DaySummarySheet: View {
    var model: DayLogModel
    var day: Date
    var onClose: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let summary = DaySummary(model: model, day: day, now: now)
            VStack(spacing: 0) {
                DaySummaryToolbar(subtitle: summary.subtitle, onClose: onClose)
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
            }
        }
        .environment(\.colorScheme, .light)
        .presentationDetents([.medium, .large])
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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

    init(model: DayLogModel, day: Date, now: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: day)
        let record = model.historyRecord(on: day, calendar: calendar)
        // "20 Apr 2026" as in Figma: Home's date label with the year.
        subtitle = "\(HomeTimeline.dateLabel(day, calendar: calendar)) \(calendar.component(.year, from: day))"
        isEmpty = record == nil

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
                 identifier: "daySummaryStarted"),
            Time(symbol: "steeringwheel", label: "Driving",
                 value: HomeTimeline.drivingLabel(minutes: record?.drivingMinutes),
                 identifier: "daySummaryDriving"),
            Time(symbol: "stop.circle", label: "Day closed",
                 value: record?.end.map { HomeTimeline.clockLabel($0, relativeTo: day, calendar: calendar) } ?? "?",
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
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 20))
        layout {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 && !stacked {
                    FadedRule(axis: .vertical).frame(width: 1, height: 44)
                }
                HomeValueColumn(symbol: item.symbol, label: item.label, value: item.value)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(item.identifier)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Figma "Toolbar - Top - Sheet": orange grabber, centred title and date, close button on the right.
private struct DaySummaryToolbar: View {
    var subtitle: String
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.tachoOrange)
                .frame(width: 36, height: 5)
                .padding(.top, 5)
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                // Balances the close button so the title stays centred.
                Color.clear.frame(width: 44, height: 44)
                VStack(spacing: 0) {
                    Text("Day summary")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier("daySummaryDate")
                }
                .foregroundStyle(Color.tachoTextOnLight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.tachoTextOnDark)
                        .frame(width: 44, height: 44)
                        .background(TachoTheme.orangeStrong, in: Circle())
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("closeSheetButton")
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}
