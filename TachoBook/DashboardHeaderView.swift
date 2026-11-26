//
//  DashboardHeaderView.swift
//  TachoBook
//

import SwiftUI

/// Figma "Main Top Header": the viewed weekday and date with the week strip. On an earlier day the round orange
/// Home button returns to today (owner decision 16.11.2026, Figma 838:33650), at the far right.
/// The trailing slot holds an optional per-tab action (`HeaderAction`), e.g. "Add" on History, before it.
public struct DashboardHeaderView: View {
    /// The day shown (today, or an earlier day after swiping back).
    public var date: Date
    public var today: Date
    /// The week strip is for swiping back on Home; the other tabs show only the weekday and date.
    public var showsDateStrip: Bool
    public var onToday: () -> Void
    /// Tap on a reachable date: the number of days back to show.
    public var onSelect: (Int) -> Void
    /// VoiceOver adjust: +1 goes toward today, −1 to the previous day.
    public var onAdjust: (Int) -> Void
    /// The trailing glass button; nil leaves the slot empty.
    public var trailingAction: HeaderAction?

    public init(date: Date = Date(), today: Date? = nil, showsDateStrip: Bool = true, onToday: @escaping () -> Void = {},
                onSelect: @escaping (Int) -> Void = { _ in }, onAdjust: @escaping (Int) -> Void = { _ in },
                trailingAction: HeaderAction? = nil) {
        self.trailingAction = trailingAction
        self.date = date
        self.today = today ?? date
        self.showsDateStrip = showsDateStrip
        self.onToday = onToday
        self.onSelect = onSelect
        self.onAdjust = onAdjust
    }

    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: today) }
    @Namespace private var selectionCircle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        // At accessibility text sizes the buttons go under the title, so the weekday is not squeezed into syllables.
        let titleRow = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(alignment: .top, spacing: 5))
        VStack(spacing: 8) {
            titleRow {
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

                // Figma 838:33650 "Row": the tab's action, then the round Home button at the far right.
                HStack(spacing: 16) {
                    if let trailingAction {
                        HeaderActionButton(action: trailingAction)
                    }
                    if !isToday {
                        HomeTodayButton(action: onToday)
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, 16)

            if showsDateStrip {
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
        }
        .padding(.bottom, 10)
    }
}

/// A per-tab action in the header's trailing slot. Kept generic so each tab can pass its own (History: Add past
/// shift; Home: Add past shift while a past day shows the No activities widget).
public struct HeaderAction {
    /// The visible text, e.g. "Add".
    public var title: String
    public var systemImage: String
    /// What VoiceOver reads when it differs from the visible text, e.g. "Add past shift".
    public var accessibilityLabel: String
    public var identifier: String
    public var action: () -> Void

    public init(title: String, systemImage: String, accessibilityLabel: String? = nil, identifier: String,
                action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel ?? title
        self.identifier = identifier
        self.action = action
    }
}

/// Figma "Button - Liquid Glass - Text", Tinted=False (Add Past Shift · 01, 814:11488): symbol and text in white
/// over Liquid Glass with the brand-blue tint, as the former settings gear. 48 pt high at the default size
/// (36 pt content + 6 pt padding), 20 pt side padding; it grows with Dynamic Type and has no fixed width.
struct HeaderActionButton: View {
    var action: HeaderAction

    var body: some View {
        Button(action: action.action) {
            Text("\(Image(systemName: action.systemImage)) \(action.title)")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.tachoTextOnDark)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .frame(minHeight: 48)
                .contentShape(Capsule())
                .glassEffect(.regular.tint(Color.tachoBlue.opacity(0.5)).interactive(), in: Capsule())
                .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
        .fixedSize()
        // Figma "Trailing": 8 pt from the top of the title row.
        .padding(.top, 8)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityIdentifier(action.identifier)
    }
}

/// Figma "Button Group 1" (838:34313): a 44 pt orange circle with house.circle.fill in white; it goes back to today.
/// Solid fill in the contrast-checked orange: translucent glass over the sky failed the contrast audit (Today button).
struct HomeTodayButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            // A fixed size inside the fixed 44 pt circle; larger text sizes get the Large Content Viewer instead.
            Image(systemName: "house.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.tachoTextOnDark)
                .frame(width: 44, height: 44)
                .background(TachoTheme.orangeStrong, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Centred on the 48 pt Add button, which sits 8 pt below the top of the title row.
        .padding(.top, 10)
        .accessibilityLabel("Today")
        .accessibilityShowsLargeContentViewer()
        .accessibilityHint("Back to today")
        .accessibilityIdentifier("todayButton")
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
