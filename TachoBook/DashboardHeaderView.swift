//
//  DashboardHeaderView.swift
//  TachoBook
//

import SwiftUI

public struct DashboardHeaderView: View {
    public var date: Date
    public var title: String?
    public var subtitle: String?

    public init(date: Date = Date(), title: String? = nil, subtitle: String? = nil) {
        self.date = date
        self.title = title
        self.subtitle = subtitle
    }

    private var displayTitle: String {
        title ?? date.formatted(Date.FormatStyle().weekday(.wide))
    }

    private var displaySubtitle: String {
        subtitle ?? date.formatted(Date.FormatStyle().day().month(.wide))
    }

    private var weekDays: [(day: String, weekday: String, opacity: Double, isSelected: Bool)] {
        let calendar = Calendar.current
        return (-2...2).compactMap { offset in
            guard let target = calendar.date(byAdding: .day, value: offset, to: date) else { return nil }
            let dayStr = target.formatted(Date.FormatStyle().day())
            let weekdayStr = target.formatted(Date.FormatStyle().weekday(.abbreviated))
            let isSelected = (offset == 0)
            let opacity = isSelected ? 1.0 : (abs(offset) == 1 ? 0.5 : 0.25)
            return (dayStr, weekdayStr, opacity, isSelected)
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Title Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(.largeTitle, weight: .semibold))
                        .foregroundColor(.white)
                    Text(displaySubtitle)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.white)
                }

                Spacer()

                // Trailing History Glass Button
                Button(action: {}) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background {
                            ZStack {
                                Color(red: 17/255, green: 107/255, blue: 147/255, opacity: 0.45)
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                            }
                        }
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.45),
                                            Color.white.opacity(0.12)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
                }
            }
            .padding(.horizontal, 16)

            // Week Day Selector Strip
            HStack(spacing: 8) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, item in
                    WeekDayItem(
                        day: item.day,
                        weekday: item.weekday,
                        opacity: item.opacity,
                        isSelected: item.isSelected
                    )
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

struct WeekDayItem: View {
    var day: String
    var weekday: String
    var opacity: Double
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.system(.title3, weight: isSelected ? .bold : .regular))
                .foregroundColor(.white.opacity(opacity))
            Text(weekday)
                .font(.caption)
                .foregroundColor(.white.opacity(opacity))
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}
