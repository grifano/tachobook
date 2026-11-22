//
//  NoActivitiesWidget.swift
//  TachoBook
//

import SwiftUI

/// Figma "Widget - No activities" (Past Day Covered - 02, 838:33654): a past day on Home without a shift. The top
/// part always shows; the driver's last activity and "Tap to see this day" only when an earlier shift exists.
/// Text is navy on the light card (TachoTheme), the icons brand blue, the button orange with white text.
struct NoActivitiesWidget: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The latest shift before the day; nil shows only the top part.
    var lastShift: DutyPeriod?
    /// Opens the day of the last shift (Home or History); nil when there is nothing to open.
    var onOpen: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero
            if let lastShift {
                FadedRule().frame(height: 1)
                lastActivity(lastShift)
                if let onOpen {
                    Button(action: onOpen) { buttonLabel }
                        .buttonStyle(HomeCapsuleButtonStyle())
                        .accessibilityHint("Opens the day of your last activity")
                        .accessibilityIdentifier("seeThisDayButton")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The Home widget surface, with the shadow on the card only: `homeWidgetBackground()` also shadows the content,
        // which darkened the white button text enough to fail the accessibility audit's contrast check.
        .background {
            let shape = RoundedRectangle(cornerRadius: TachoTheme.widgetRadius, style: .continuous)
            ZStack {
                shape.fill(.ultraThinMaterial).environment(\.colorScheme, .light)
                shape.fill(TachoTheme.widgetFill)
            }
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
        // A tap anywhere on the card does what the button does.
        .contentShape(RoundedRectangle(cornerRadius: TachoTheme.widgetRadius, style: .continuous))
        .onTapGesture { if lastShift != nil { onOpen?() } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("noActivitiesWidget")
    }

    /// Figma "Hero": the 56 pt tinted circle with calendar.badge.minus, the title and the subtitle.
    private var hero: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.minus")
                .font(.title2)
                .foregroundStyle(Color.tachoBlue)
                .frame(width: 56, height: 56)
                .background(Color.tachoBlue.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Last shift closed")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("No activities for this day")
                    .font(.caption)
            }
            .foregroundStyle(Color.tachoTextOnLight)
            .homeTextFit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("noActivitiesHero")
    }

    /// "Your last activity · Fr 16 Oct 2026" and Day started, Driving and Day closed of that shift, formatted as
    /// in the past-day summary.
    private func lastActivity(_ shift: DutyPeriod) -> some View {
        let day = DayHistory.recordDay(shift)
        let columns = [
            HomeValueColumn(symbol: "play.circle", label: "Day started",
                            value: shift.start.map { HomeTimeline.clockLabel($0, relativeTo: day) } ?? "?",
                            detail: ShiftPlaceLine(place: shift.startPlace, recordedAt: shift.start)),
            HomeValueColumn(symbol: "steeringwheel", label: "Driving",
                            value: HomeTimeline.drivingLabel(minutes: shift.drivingMinutes)),
            HomeValueColumn(symbol: "stop.circle", label: "Day closed",
                            value: shift.end.map { HomeTimeline.clockLabel($0, relativeTo: day) } ?? "?",
                            detail: ShiftPlaceLine(place: shift.endPlace, recordedAt: shift.end)),
        ]
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        return VStack(alignment: .leading, spacing: 16) {
            Label("Your last activity \u{00B7} \(HomeTimeline.lastActivityDate(day))", systemImage: "info.circle.fill")
                .labelStyle(SpacedLabelStyle())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.tachoTextOnLight)
                .homeTextFit()
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("lastActivityTitle")
            layout {
                ForEach(columns.indices, id: \.self) { index in
                    if index > 0 && !isLarge {
                        FadedRule(axis: .vertical).frame(width: 1, height: 44)
                    }
                    columns[index].accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Figma "Button - Content Area": full width, orange, info icon and "Tap to see this day" in white.
    private var buttonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle.fill").accessibilityHidden(true)
            Text("Tap to see this day")
        }
        .font(.body)
        .foregroundStyle(Color.tachoTextOnDark)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(TachoTheme.orangeStrong, in: Capsule())
        .contentShape(Capsule())
    }
}
