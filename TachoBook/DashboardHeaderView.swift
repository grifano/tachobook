//
//  DashboardHeaderView.swift
//  TachoBook
//

import SwiftUI

/// Figma "Main Top Header": the viewed weekday and date with the week strip. After swiping back
/// a Today button joins the settings icon (not in Figma; a solid dark capsule so its text keeps contrast).
public struct DashboardHeaderView: View {
    /// The day shown (today, or an earlier day after swiping back).
    public var date: Date
    public var today: Date
    public var onToday: () -> Void
    /// Tap on a reachable date: the number of days back to show.
    public var onSelect: (Int) -> Void
    /// VoiceOver adjust: +1 goes toward today, −1 to the previous day.
    public var onAdjust: (Int) -> Void

    public init(date: Date = Date(), today: Date? = nil, onToday: @escaping () -> Void = {},
                onSelect: @escaping (Int) -> Void = { _ in }, onAdjust: @escaping (Int) -> Void = { _ in }) {
        self.date = date
        self.today = today ?? date
        self.onToday = onToday
        self.onSelect = onSelect
        self.onAdjust = onAdjust
    }

    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: today) }
    @Namespace private var selectionCircle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.largeTitle.weight(.semibold))
                        .contentTransition(.opacity)
                        .accessibilityAddTraits(.isHeader)
                    Text(HomeTimeline.headerDate(date))
                        .font(.subheadline.weight(.medium))
                        .contentTransition(.opacity)
                        .accessibilityIdentifier("headerDate")
                }
                .foregroundStyle(Color.tachoTextOnDark)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isToday {
                    Button(action: onToday) {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.tachoTextOnDark)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            // Solid dark fill: translucent glass over the sky failed the contrast audit.
                            .background(Color.tachoTextOnLight, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Back to today")
                    .accessibilityIdentifier("todayButton")
                    .transition(.opacity)
                }

                // Settings has no destination yet; shown as in Figma without navigation.
                Image(systemName: "gear")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.tachoTextOnDark)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(Color.tachoBlue.opacity(0.5)), in: Circle())
                    .environment(\.colorScheme, .dark)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(HomeTimeline.dateStrip(today: today), id: \.offset) { day in
                    WeekDayItem(day: day, isSelected: Calendar.current.isDate(day.date, inSameDayAs: date),
                                isViewedToday: isToday,
                                reach: DayHistory.daysBack(of: day.date, from: today),
                                circle: selectionCircle, movesCircle: !reduceMotion,
                                onSelect: onSelect, onAdjust: onAdjust)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.bottom, 10)
    }
}

/// One date in the fixed strip. The selected day carries the circle (it moves between dates);
/// a date the swipe can reach (`reach` = days back, today … `maxDaysBack`) is a button; the others
/// do nothing and keep their look.
struct WeekDayItem: View {
    var day: HomeTimeline.WeekStripDay
    var isSelected: Bool
    var isViewedToday = true
    var reach: Int?
    var circle: Namespace.ID
    var movesCircle = true
    var onSelect: (Int) -> Void = { _ in }
    var onAdjust: (Int) -> Void = { _ in }

    private var fullDate: String { day.date.formatted(date: .complete, time: .omitted) }

    var body: some View {
        if !isSelected, let reach {
            Button { onSelect(reach) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(reach == 0 ? "Today, \(fullDate)" : fullDate)
                .accessibilityIdentifier("weekStripDay")
        } else {
            content
                // Only the selected day is announced; dates the swipe cannot reach stay silent.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isSelected ? "\(isViewedToday ? "Today, " : "")\(fullDate)" : "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHidden(!isSelected)
                // The selected day is adjustable: swipe up or down to move to the next or previous day.
                .accessibilityAdjustableAction { direction in
                    guard isSelected else { return }
                    onAdjust(direction == .increment ? 1 : -1)
                }
                .accessibilityIdentifier(isSelected ? (isViewedToday ? "weekStripToday" : "weekStripSelected") : "weekStripOutOfRange")
        }
    }

    private var content: some View {
        VStack(spacing: 4) {
            Text(day.date.formatted(.dateTime.day()))
                .font(.title3)
            Text(day.date.formatted(.dateTime.weekday(.short)))
                .font(.caption)
        }
        .foregroundStyle(Color.tachoTextOnDark)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background { if isSelected { selectionCircle } }
        .contentShape(Rectangle())
    }

    /// Figma "Week Day" BG: 44 pt circle, #E4E4E4 at 30 % fill inside a 44 % layer.
    /// With Reduce Motion it fades in place instead of travelling to the new date.
    @ViewBuilder private var selectionCircle: some View {
        let circleShape = Circle()
            .fill(Color(red: 228/255, green: 228/255, blue: 228/255).opacity(0.3 * 0.44))
            .frame(width: 44, height: 44)
        if movesCircle {
            circleShape.matchedGeometryEffect(id: "selection", in: circle)
        } else {
            circleShape.transition(.opacity)
        }
    }
}
