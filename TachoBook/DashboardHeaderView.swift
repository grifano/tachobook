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
    /// VoiceOver adjust: +1 goes toward today, −1 to the previous day.
    public var onAdjust: (Int) -> Void

    public init(date: Date = Date(), today: Date? = nil, onToday: @escaping () -> Void = {},
                onAdjust: @escaping (Int) -> Void = { _ in }) {
        self.date = date
        self.today = today ?? date
        self.onToday = onToday
        self.onAdjust = onAdjust
    }

    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: today) }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(HomeTimeline.headerDate(date))
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("headerDate")
                }
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isToday {
                    Button(action: onToday) {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            // Solid dark fill: translucent glass over the sky failed the contrast audit.
                            .background(TachoTheme.blueText, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Back to today")
                    .accessibilityIdentifier("todayButton")
                }

                // Settings has no destination yet; shown as in Figma without navigation.
                Image(systemName: "gear")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(Color.tachoBlue.opacity(0.5)), in: Circle())
                    .environment(\.colorScheme, .dark)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(HomeTimeline.weekStrip(around: date), id: \.offset) { day in
                    WeekDayItem(day: day, isViewedToday: isToday, onAdjust: onAdjust)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.bottom, 10)
    }
}

/// `day.isToday` marks the viewed day (the centre of the strip).
struct WeekDayItem: View {
    var day: HomeTimeline.WeekStripDay
    var isViewedToday = true
    var onAdjust: (Int) -> Void = { _ in }

    /// Figma fades neighbours to 50 % and 25 % opacity; solid lighter grays keep the
    /// hierarchy with readable contrast (the audit rejects translucent text).
    private var whiteLevel: Double {
        day.isToday ? 1 : (abs(day.offset) == 1 ? 0.93 : 0.86)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(day.date.formatted(.dateTime.day()))
                .font(.title3)
            Text(day.date.formatted(.dateTime.weekday(.short)))
                .font(.caption)
        }
        .foregroundStyle(Color(white: whiteLevel))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            // Figma "Week Day" BG: 44 pt circle, #E4E4E4 at 30 % fill inside a 44 % layer.
            if day.isToday {
                Circle()
                    .fill(Color(red: 228/255, green: 228/255, blue: 228/255).opacity(0.3 * 0.44))
                    .frame(width: 44, height: 44)
            }
        }
        // Only today is announced; the neighbouring days carry no action yet.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.isToday
            ? "\(isViewedToday ? "Today, " : "")\(day.date.formatted(date: .complete, time: .omitted))" : "")
        .accessibilityAddTraits(day.isToday ? .isSelected : [])
        .accessibilityHidden(!day.isToday)
        // The selected day is adjustable: swipe up or down to move to the next or previous day.
        .accessibilityAdjustableAction { direction in
            guard day.isToday else { return }
            onAdjust(direction == .increment ? 1 : -1)
        }
        .accessibilityIdentifier(day.isToday ? (isViewedToday ? "weekStripToday" : "weekStripSelected") : "weekStripDay")
    }
}
