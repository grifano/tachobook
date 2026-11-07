//
//  ViolationSheet.swift
//  TachoBook
//

import SwiftUI

/// Every text the violation screens show, from Figma Flow 3, Flow 4 and Flow 3 View History, and spec Appendix G.
/// Dynamic parts come from the records; dates follow the device locale.
public enum ViolationCopy {
    public static func title(_ violation: Violation) -> String {
        violation.kind == .dutyLimit ? "Shift limit passed" : "Daily rest under 9h"
    }

    /// Flow 3 · 02/04 (over Home) names the limit; the Flow 4 sheet uses the row title.
    public static func homeSheetTitle(_ violation: Violation) -> String {
        violation.kind == .dutyLimit ? "\(violation.limitHours)h limit passed" : title(violation)
    }

    /// Flow 3: "Over by 0:30 since 18:40".
    public static func homeSheetSubtitle(_ violation: Violation, now: Date, calendar: Calendar = .current) -> String {
        guard violation.kind == .dutyLimit else { return sheetSubtitle(violation, calendar: calendar) }
        return "Over by \(duration(violation.overtimeSeconds)) since "
            + HomeTimeline.clockLabel(violation.began, relativeTo: now, calendar: calendar)
    }

    /// Flow 4: "Mon 19 Oct · over by 0:30 since 18:40" or "Sun 18 Oct · rest 8:15 in 24 h".
    public static func sheetSubtitle(_ violation: Violation, calendar: Calendar = .current) -> String {
        let day = weekdayDayMonth(violation.day, calendar: calendar)
        switch violation.kind {
        case .dutyLimit:
            return "\(day) · over by \(duration(violation.overtimeSeconds)) since "
                + HomeTimeline.clockLabel(violation.began, relativeTo: violation.day, calendar: calendar)
        case .shortRest:
            return "\(day) · rest \(duration(violation.restSeconds)) in 24 h"
        }
    }

    public static func redLine(_ violation: Violation) -> String {
        violation.kind == .dutyLimit
            ? "You\u{2019}ve passed your \(violation.limitHours)-hour shift limit."
            : "Your daily rest was shorter than 9 hours."
    }

    public static let reminder = "Print a tachograph log and write the reason on it by hand when you stop."

    /// Flow 4 · 03: "Printout done on 19 Oct. Carry it with you until 14 Dec · 56 days left." After the carry period
    /// the row's wording (Flow 4 · 07) is used.
    public static func printoutLine(printedAt: Date, status: PrintoutCarry.Status, calendar: Calendar = .current) -> String {
        let printed = HomeTimeline.dateLabel(printedAt, calendar: calendar)
        guard let until = status.carryUntil, let left = status.daysLeft, left >= 0 else {
            return "Printout done on \(printed) · no need to carry it."
        }
        return "Printout done on \(printed). Carry it with you until "
            + "\(HomeTimeline.dateLabel(until, calendar: calendar)) · \(daysLeft(left))."
    }

    /// Flow 4 · 01, 04, 07.
    public static func rowSubtitle(_ violation: Violation, status: PrintoutCarry.Status, calendar: Calendar = .current) -> String {
        switch (status.carryUntil, status.isOlder) {
        case (let until?, false):
            return "Carry until \(HomeTimeline.dateLabel(until, calendar: calendar)) · \(daysLeft(status.daysLeft ?? 0))"
        case (_?, true):
            return "\(HomeTimeline.dateLabel(violation.day, calendar: calendar)) · no need to carry it"
        case (nil, false):
            return "No printout marked yet · ?"
        case (nil, true):
            return "No printout marked · ?"
        }
    }

    public static func daysLeft(_ days: Int) -> String {
        days == 1 ? "1 day left" : "\(days) days left"
    }

    /// History Day summary subtitle (decision 20 c).
    public static func violationCount(_ count: Int) -> String {
        switch count {
        case 0: "No violations"
        case 1: "1 violation"
        default: "\(count) violations"
        }
    }

    public static let noteLabel = "Write on your printout"
    /// Spec Appendix G, approved by Serhii on 19.10.2026.
    public static let note = """
        Art. 12 EC 561/2006
        Date: … Time: … – …
        To ensure the safety of the vehicle and load and to reach a suitable stopping place, I moved my daily rest beyond 24 hours. Reason: (parking … full at hh:mm / road closure on … / bad weather / accident on …).
        Name, surname, signature
        """
    public static let noteFootnote = "Write on the back, by hand, at the latest when you stop. Be specific: place and time."

    /// "0:30": hours and minutes.
    static func duration(_ seconds: Int) -> String { DayLogModel.durationString(seconds: seconds) }

    /// "Mon 19 Oct" in the device locale.
    static func weekdayDayMonth(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter.string(from: date)
    }
}

/// Figma "Violation Sheet": Flow 3 · 02/04 over Home (✕ only), and Flow 4 · 02/03/05 from the Violations tab or
/// History with the printout buttons. Values are recomputed every second from the records.
struct ViolationSheet: View {
    enum Style {
        /// Flow 3 · 02/04: opened from Home's alert or red overtime; no printout buttons.
        case home
        /// Flow 4: with "Printout done", "Skip for now" and "Mark as not done".
        case list
    }

    var model: DayLogModel
    var key: ViolationKey
    var style: Style
    var onClose: () -> Void

    @State private var askWhen = false
    @State private var enterTime = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            if let violation = model.violation(for: key, now: now) {
                content(violation, now: now)
            } else {
                // An edit removed it from the records (R-E01).
                Color.clear.onAppear(perform: onClose)
            }
        }
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.white)
        // Flow 4 · 08.
        .alert("When did you print it?", isPresented: $askWhen) {
            Button("Earlier") { enterTime = true }
            Button("Just now") { markPrintout(at: Date()) }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text("Printed it before and forgot to mark it? Tap Earlier.")
        }
        // Flow 4 · 09: the time sheet used for shift start and end.
        .sheet(isPresented: $enterTime) {
            if let violation = model.violation(for: key, now: Date()) {
                TimeEntrySheet(kind: .printout, initialDate: Date(),
                               check: { model.checkPrintout($0, for: violation, now: Date()) },
                               onConfirm: { date in
                                   model.markPrintout(date, for: violation, now: Date())
                                   enterTime = false
                               },
                               onCancel: { enterTime = false })
            }
        }
    }

    private func content(_ violation: Violation, now: Date) -> some View {
        let printedAt = model.printout(for: key)
        let status = model.carryStatus(of: violation, now: now)
        return VStack(spacing: 0) {
            TitledSheetToolbar(
                title: style == .home ? ViolationCopy.homeSheetTitle(violation) : ViolationCopy.title(violation),
                subtitle: style == .home ? ViolationCopy.homeSheetSubtitle(violation, now: now)
                                         : ViolationCopy.sheetSubtitle(violation),
                onClose: onClose)
            ScrollView {
                VStack(spacing: 32) {
                    gauge(violation, now: now)
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text(ViolationCopy.redLine(violation))
                                .foregroundStyle(TachoTheme.alertRedText)
                                .accessibilityIdentifier("violationRedLine")
                            if let printedAt {
                                Text(ViolationCopy.printoutLine(printedAt: printedAt, status: status))
                                    .foregroundStyle(TachoTheme.successGreenText)
                                    .accessibilityIdentifier("printoutLine")
                            } else {
                                Text(ViolationCopy.reminder)
                                    .foregroundStyle(Color.tachoTextOnLight)
                            }
                        }
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        PrintoutNoteCard()
                        if style == .list { buttons(violation, printedAt: printedAt) }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, style == .home ? 37 : 0)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The Work gauge for a shift past its limit, the Rest gauge for a short rest; with the day's icon row.
    private func gauge(_ violation: Violation, now: Date) -> some View {
        let used = model.historyReducedRests(onDay: violation.day, now: now)
        let seconds = violation.kind == .dutyLimit ? violation.dutySeconds : violation.restSeconds
        return GaugeProgressView(
            limit: "\(violation.limitHours)h", value: HomeTimeline.clockDuration(seconds: seconds),
            progress: Double(seconds) / (Double(violation.limitHours) * 3600),
            tint: violation.kind == .dutyLimit ? .tachoOrange : .tachoBlue,
            countIcon: violation.kind == .dutyLimit ? .hammer : .bed, reducedRestsUsed: used)
            .accessibilityIdentifier("violationGauge")
    }

    @ViewBuilder
    private func buttons(_ violation: Violation, printedAt: Date?) -> some View {
        VStack(spacing: 8) {
            if printedAt == nil {
                Button { askWhen = true } label: {
                    SheetCapsuleLabel(title: "Printout done", fill: TachoTheme.orangeStrong)
                }
                .buttonStyle(HomeCapsuleButtonStyle())
                .disabled(model.storageError != nil)
                .accessibilityIdentifier("printoutDoneButton")
                Button("Skip for now", action: onClose)
                    .buttonStyle(SheetTextButtonStyle())
                    .accessibilityIdentifier("skipForNowButton")
            } else {
                // Flow 4 · 03: the green "Printout done" shows the state; it is not a second action.
                SheetCapsuleLabel(title: "Printout done", fill: TachoTheme.successGreenText)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("printoutDoneState")
                Button("Mark as not done") { model.clearPrintout(for: violation.key) }
                    .buttonStyle(SheetTextButtonStyle())
                    .disabled(model.storageError != nil)
                    .accessibilityIdentifier("markNotDoneButton")
            }
        }
    }

    private func markPrintout(at date: Date) {
        guard let violation = model.violation(for: key, now: date) else { return }
        model.markPrintout(date, for: violation, now: date)
    }
}

/// Figma "Printout Note": the Art. 12 template from spec Appendix G with its label and footnote.
struct PrintoutNoteCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ViolationCopy.noteLabel)
                .font(.footnote.weight(.semibold))
            Text(ViolationCopy.note)
                .font(.body)
            Text(ViolationCopy.noteFootnote)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(Color.tachoTextOnLight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TachoTheme.noteFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("printoutNote")
    }
}

/// Figma "Button - Content Area", filled: a full-width capsule with white text.
struct SheetCapsuleLabel: View {
    var title: String
    var fill: Color

    var body: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(Color.tachoTextOnDark)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(fill, in: Capsule())
            .contentShape(Capsule())
    }
}

/// Figma "Button - Content Area", plain: "Skip for now", "Mark as not done". Navy text (Figma's tertiary gray is
/// below the contrast the audit requires; F9: only navy text on light surfaces).
struct SheetTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Color.tachoTextOnLight)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Figma "Toolbar - Top - Sheet" with a close button on the right only: orange grabber, centred title and
/// subtitle (Day summary, violation sheets).
struct TitledSheetToolbar: View {
    var title: String
    var subtitle: String
    var subtitleIdentifier = "sheetSubtitle"
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
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("sheetTitle")
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier(subtitleIdentifier)
                }
                .foregroundStyle(Color.tachoTextOnLight)
                .multilineTextAlignment(.center)
                // One line at standard sizes; longer subtitles wrap at larger text sizes instead of being cut.
                .homeTextFit()
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
