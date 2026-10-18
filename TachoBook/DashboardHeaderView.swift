//
//  DashboardHeaderView.swift
//  TachoBook
//

import SwiftUI

/// Figma "Main Top Header": the current weekday, date and time with the week strip.
public struct DashboardHeaderView: View {
    public var date: Date

    public init(date: Date = Date()) {
        self.date = date
    }

    private var subtitle: String {
        let day = date.formatted(.dateTime.day().month(.wide).year())
        return "\(day) \(HomeTimeline.clockLabel(date, relativeTo: date))"
    }

    private var weekDays: [(day: String, weekday: String, opacity: Double)] {
        let calendar = Calendar.current
        return (-2...2).compactMap { offset in
            guard let target = calendar.date(byAdding: .day, value: offset, to: date) else { return nil }
            // Figma fades neighbours to 50 % and 25 % opacity; solid lighter grays keep the
            // hierarchy with readable contrast (the audit rejects translucent text).
            let opacity = offset == 0 ? 1.0 : (abs(offset) == 1 ? 0.93 : 0.86)
            return (target.formatted(.dateTime.day()), target.formatted(.dateTime.weekday(.short)), opacity)
        }
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .accessibilityIdentifier("headerDateTime")
                }
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, item in
                    WeekDayItem(day: item.day, weekday: item.weekday, opacity: item.opacity)
                }
            }
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
        }
        .padding(.bottom, 10)
    }
}

struct WeekDayItem: View {
    var day: String
    var weekday: String
    /// White level of the text: 1 for today, lower for the neighbouring days.
    var opacity: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.title3)
            Text(weekday)
                .font(.caption)
        }
        .foregroundStyle(Color(white: opacity))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}
