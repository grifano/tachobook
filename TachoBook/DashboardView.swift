//
//  DashboardView.swift
//  TachoBook
//

import SwiftUI

/// Home from Figma "Flow 1 - Log Day Shift". Every displayed value is derived
/// from persisted timestamps and the current time.
public struct DashboardView: View {
    enum HomeSheet: String, Identifiable {
        case startShift
        case closeShift
        case editDayStart
        case editDayEnd
        case driving
        case pastDayStart
        case pastDayEnd
        case pastDriving
        /// Flow 3 · 02/04: the current shift past its limit.
        case violation

        var id: String { rawValue }
    }

    /// Flow 3 · 00 and 00b: in-app alerts before and after the applicable limit (decisions 12 and 13).
    enum LimitAlert: Equatable {
        case approaching(minutes: Int, limit: Int, limitEnd: String)
        case passed(limit: Int, overtime: String)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State public var model: DayLogModel
    @State private var sheet: HomeSheet?
    @State private var tabOverride: HomeTab?
    @State private var showDrivingAlert = false
    @State private var drivingAlertPending = false
    /// The time the full 11 h rest ends, shown in the early-start warning at 3 of 3; nil while the alert is hidden.
    @State private var earlyStartRestEnd: String?
    @State private var limitAlert: LimitAlert?
    /// 0 is today (the live Home); 1…`DayHistory.maxDaysBack` are earlier days. View state only:
    /// browsing never writes to the store.
    @State private var daysBack = DashboardView.initialDaysBack
    @State private var slideEdge: Edge = .trailing
    /// True while a horizontal swipe is under way, and shortly after it ends. A swipe across a
    /// wide capsule or card must never count as a tap on it.
    @GestureState private var isSwiping = false
    @State private var swipeEndedAt: Date?
    /// The small "Older days are in History." label after a swipe past the oldest reachable day.
    @State private var showLimitHint = false
    @State private var limitHintToken = 0
    /// Finds the country for a new Start or Close (a stub in UI tests).
    private let locator = CountryLocator.forLaunch

    /// DEBUG only: `-startDaysBack 1` opens an earlier day, for screenshots and audits.
    private static var initialDaysBack: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-startDaysBack"), index + 1 < args.count, let value = Int(args[index + 1]) {
            return min(max(value, 0), DayHistory.maxDaysBack)
        }
        #endif
        return 0
    }

    public init(model: DayLogModel = DayLogModel.dashboardModel()) {
        self._model = State(initialValue: model)
    }

    /// The default tab follows the shift state; the toggle only overrides the view.
    private var tab: Binding<HomeTab> {
        let defaultTab: HomeTab = daysBack == 0 && model.isResting ? .rest : .work
        return Binding(
            get: { tabOverride ?? defaultTab },
            set: { newValue in
                withAnimation { tabOverride = newValue == defaultTab ? nil : newValue }
            }
        )
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            VStack(spacing: 0) {
                DashboardHeaderView(date: daysBack == 0 ? now : DayHistory.day(daysBack: daysBack, from: now),
                                    today: now, onToday: { step(to: 0) }, onSelect: { step(to: $0) },
                                    onAdjust: { step(to: daysBack - $0) })
                ScrollView {
                    VStack(spacing: 20) {
                        if daysBack == 0 {
                            content(now: now)
                        } else {
                            pastDayContent(now: now)
                        }
                        if let error = model.storageError {
                            Text(error).font(.footnote).foregroundStyle(Color.tachoTextOnDark)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                    .id(daysBack)
                    .transition(dayTransition)
                    .allowsHitTesting(!isSwiping)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(daySwipe)
                .overlay(alignment: .top) {
                    if showLimitHint {
                        LimitHint(text: Self.limitHintText)
                            // Straddles the top edge of the card, just under the date strip, clear of the card title.
                            .padding(.top, -10)
                            .transition(.opacity)
                    }
                }
            }
        }
        // Any tap dismisses the hint; it also dismisses itself after a few seconds.
        .simultaneousGesture(TapGesture().onEnded { if showLimitHint { dismissLimitHint() } })
        .task(id: limitHintToken) {
            guard showLimitHint else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            dismissLimitHint()
        }
        .background {
            ZStack(alignment: .top) {
                Image("DashboardBackground")
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.2))
                // Darker top so the white header and week strip keep their contrast over the sky.
                LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 480)
            }
            .ignoresSafeArea()
        }
        .onChange(of: model.isResting) { withAnimation { tabOverride = nil } }
        .onChange(of: daysBack) { tabOverride = nil }
        .sheet(item: $sheet, onDismiss: presentPendingDrivingAlert) { sheet in
            sheetContent(sheet)
        }
        .alert("Shift closed", isPresented: $showDrivingAlert) {
            Button("Later", role: .cancel) {}
            Button("Add time") { present(.driving) }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text("Add your total driving time for this shift.")
        }
        // Approved copy (decision 2, 02.11.2026); a start before 11 h is warned about, never blocked.
        .alert("All 3 reduced rests used", isPresented: earlyStartAlert, presenting: earlyStartRestEnd) { _ in
            Button("Keep resting", role: .cancel) {}
            Button("Start anyway", role: .destructive) { present(.startShift) }
        } message: { time in
            Text("Starting now breaks the rest rules. Rest until \(time) for the full 11 hours.")
        }
        // Flow 3 · 00 (approved copy): 15 min before the applicable limit, once.
        .alert(approachingTitle, isPresented: limitAlertShown(approaching: true)) {
            Button("End of day") { present(.closeShift) }
            Button("Keep working") {}
                .keyboardShortcut(.defaultAction)
        } message: {
            if case .approaching(_, _, let limitEnd) = limitAlert {
                Text("Start your rest by \(limitEnd) to stay within the limit. Keep working?")
            }
        }
        // Flow 3 · 00b (approved copy): once, when the limit is passed.
        .alert(passedTitle, isPresented: limitAlertShown(approaching: false)) {
            Button("Later") {}
            Button("Show details") { present(.violation) }
                .keyboardShortcut(.defaultAction)
        } message: {
            if case .passed(_, let overtime) = limitAlert {
                Text("You\u{2019}re \(overtime) over your shift limit. Print a tachograph log when you stop.")
            }
        }
        .task {
            while !Task.isCancelled {
                checkLimitAlerts(now: Date())
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Limit alerts (decisions 2, 12, 13)

    private var approachingTitle: String {
        guard case .approaching(let minutes, let limit, _) = limitAlert else { return "" }
        return "\(minutes) min left to your \(limit)h limit"
    }

    private var passedTitle: String {
        guard case .passed(let limit, _) = limitAlert else { return "" }
        return "\u{2757} \(limit)h limit passed"
    }

    private func limitAlertShown(approaching: Bool) -> Binding<Bool> {
        Binding(get: {
            switch limitAlert {
            case .approaching: approaching
            case .passed: !approaching
            case nil: false
            }
        }, set: { if !$0 { limitAlert = nil } })
    }

    /// Shows each alert once per shift and limit, only on today's Home while the shift runs and nothing else is open.
    private func checkLimitAlerts(now: Date) {
        guard daysBack == 0, model.isShiftOpen, let start = model.dayStart, model.storageError == nil,
              sheet == nil, limitAlert == nil, !showDrivingAlert, earlyStartRestEnd == nil else { return }
        let limit = ViolationRules.applicableLimitHours(model.dutyLimitAvailability)
        let base = "\(model.dutyID.uuidString)-\(limit)h"
        if let violation = model.currentDutyViolation(now: now), violation.isOngoing {
            guard LimitAlertLog.markShown(base + "-passed") else { return }
            LimitAlertLog.markShown(base + "-approaching")
            limitAlert = .passed(limit: violation.limitHours, overtime: ViolationCopy.duration(violation.overtimeSeconds))
            return
        }
        let limitEnd = HomeTimeline.adding(hours: limit, to: start)
        let left = limitEnd.timeIntervalSince(now)
        guard left > 0, left <= LimitAlertLog.leadTime, LimitAlertLog.markShown(base + "-approaching") else { return }
        limitAlert = .approaching(minutes: Int((left / 60).rounded(.up)), limit: limit,
                                  limitEnd: HomeTimeline.clockLabel(limitEnd, relativeTo: now))
    }

    private var earlyStartAlert: Binding<Bool> {
        Binding(get: { earlyStartRestEnd != nil }, set: { if !$0 { earlyStartRestEnd = nil } })
    }

    // MARK: - States

    @ViewBuilder
    private func content(now: Date) -> some View {
        if model.isResting, tab.wrappedValue == .rest {
            // Frames 01, 06, 08: rest running.
            restWidget(now: now)
            startOfDayButton(now: now)
            summaryCard(now: now)
        } else if model.isResting {
            // Frame 09: Work tab while resting shows the frozen shift.
            workWidget(now: now)
            chipRow {
                startChip(now: now)
                doneChip(title: "End at", date: model.dayEnd, now: now)
            }
            summaryCard(now: now)
        } else if model.isShiftOpen {
            // Frames 03, 04: shift running.
            workWidget(now: now)
            chipRow {
                startChip(now: now)
                Button { present(.closeShift) } label: {
                    HomeCapsuleLabel(symbol: "stop.circle", title: "End of day", style: .primary)
                }
                .buttonStyle(HomeCapsuleButtonStyle())
                .disabled(model.storageError != nil)
                .accessibilityIdentifier("endOfDayButton")
            }
            nextRestCard(now: now)
        } else {
            // No shift recorded yet.
            workWidget(now: now)
            startOfDayButton(now: now)
        }
    }

    /// Two capsules side by side as in Figma, stacked at accessibility text sizes.
    private var chipRow: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 20)) : AnyLayout(HStackLayout(spacing: 20))
    }

    private func workWidget(now: Date) -> some View {
        let start = model.dayStart
        let subtitle = start.map {
            "\(HomeTimeline.dayLabel($0, relativeTo: now)) · Started \(HomeTimeline.clockLabel($0, relativeTo: $0))"
        } ?? "Today"
        // 13 h only at 3 of 3 without a confirmed split (R-D05; decisions 4–5, 30.10.2026).
        let limits = model.dutyLimitAvailability
        // A frozen shift is judged at its close time, a running one at now.
        // Past the applicable limit: red overtime under the timer; a tap opens the violation sheet (decisions 3, 6).
        let overtime = model.currentDutyViolation(now: now).map { violation in
            GaugeOvertime(seconds: violation.overtimeSeconds) { present(.violation) }
        }
        return workWidget(start: start, elapsed: model.shiftElapsedSeconds(at: now) ?? 0,
                          instant: model.currentRestStart ?? now, subtitle: subtitle,
                          isRestEnabled: model.isResting, labelsRelativeTo: now,
                          limitHours: HomeTimeline.dutyGaugeHours(limits), limits: limits,
                          reducedRestsUsed: model.homeReducedRests(now: now), overtime: overtime)
    }

    /// Work card for any shift. `elapsed` nil shows the "--:--" placeholder instead of zeros.
    /// `limitHours` is the gauge label; `limits` (R-D05) sets the gauge scale, the warning and the
    /// "…h limit end" rows. `reducedRestsUsed` is the blue (used) hammers of the always-visible row; nil
    /// (unknown) shows all gray.
    private func workWidget(start: Date?, elapsed: Int?, instant: Date, subtitle: String,
                            isRestEnabled: Bool, labelsRelativeTo reference: Date,
                            placeholder: String = "--:--", limitHours: Int = HomeTimeline.dutyMarkerHours.second,
                            limits: DutyLimitAvailability = .fifteenHours,
                            reducedRestsUsed: Int?, overtime: GaugeOvertime? = nil) -> some View {
        let scaleHours = HomeTimeline.dutyGaugeHours(limits)
        let warning = start.flatMap { start in
            elapsed != nil && HomeTimeline.isDutyWarning(shiftStart: start, at: instant, limitHours: scaleHours)
                ? HomeTimeline.remainingDuration(seconds: HomeTimeline.dutyRemainingSeconds(
                    shiftStart: start, at: instant, limitHours: scaleHours))
                : nil
        }
        return HomeMainWidget(
            icon: "HomeWorkIcon", iconSize: CGSize(width: 40, height: 40),
            title: "Work Time", subtitle: subtitle, accent: .tachoTextOnLight,
            tab: tab, isRestEnabled: isRestEnabled,
            gauge: GaugeProgressView(
                limit: "\(limitHours)h",
                value: elapsed.map { HomeTimeline.clockDuration(seconds: $0) } ?? placeholder,
                progress: Double(elapsed ?? 0) / (Double(scaleHours) * 3600),
                tint: .tachoOrange, warning: warning, countIcon: .hammer, reducedRestsUsed: reducedRestsUsed,
                overtime: overtime),
            limits: HomeTimeline.shownDutyMarkerHours(limits).map { hours in
                HomeLimit(label: "\(hours)h limit end",
                          value: start.map { HomeTimeline.clockLabel(HomeTimeline.adding(hours: hours, to: $0),
                                                                     relativeTo: reference) } ?? placeholder)
            })
    }

    @ViewBuilder
    private func restWidget(now: Date) -> some View {
        if let restStart = model.currentRestStart {
            // The card follows the displayed kind (a daily rest past 11 h shows as weekly).
            let kind = HomeTimeline.displayedRestKind(stored: model.restKind, restStart: restStart, now: now)
            let elapsed = HomeTimeline.elapsedSeconds(from: restStart, to: now)
            // A daily rest needs 11 h at 3 of 3 without a confirmed split (R-D05; decisions 4–5, 30.10.2026).
            let limits = model.dutyLimitAvailability
            let required = kind == .daily ? HomeTimeline.dailyRestRequiredHours(limits) : kind.requiredHours
            let milestoneHours = kind == .daily
                ? HomeTimeline.shownDailyRestMilestoneHours(limits) : [kind.milestoneHours.first, kind.milestoneHours.second]
            HomeMainWidget(
                icon: "HomeRestIcon", iconSize: CGSize(width: 40, height: 27),
                title: kind == .weekly ? "Weekly Rest" : "Rest Time",
                subtitle: "Closed \(HomeTimeline.dateLabel(restStart)) · \(HomeTimeline.clockLabel(restStart, relativeTo: restStart))",
                accent: Color.tachoTextOnLight, tab: tab, isRestEnabled: true,
                gauge: GaugeProgressView(
                    limit: "\(required)h",
                    value: HomeTimeline.clockDuration(seconds: elapsed),
                    progress: Double(elapsed) / (Double(required) * 3600),
                    tint: .tachoBlue, countIcon: .bed, reducedRestsUsed: model.homeReducedRests(now: now)),
                limits: milestoneHours.map { hours in
                    HomeLimit(label: "After \(hours)h rest",
                              value: HomeTimeline.clockLabel(HomeTimeline.adding(hours: hours, to: restStart), relativeTo: now))
                })
        }
    }

    /// Orange once the required rest is complete. At 3 of 3 without a split it counts down to 11 h and, from 9 h,
    /// stays dimmed but tappable: a tap warns before the usual Start of day sheet (decision 01.11.2026).
    private func startOfDayButton(now: Date) -> some View {
        let availability = model.startOfDayAvailability(now: now)
        return Button {
            if case .earlyStart(_, let fullRestEnd) = availability {
                earlyStartRestEnd = HomeTimeline.clockLabel(fullRestEnd, relativeTo: now)
            } else {
                present(.startShift)
            }
        } label: {
            HomeCapsuleLabel(symbol: "play.circle", title: "Start of day",
                             subtitle: availability.countdown.map { "Available in \($0)" },
                             style: availability == .available && model.storageError == nil ? .primary : .dimmed,
                             titleFont: .headline, subtitleFont: .footnote)
        }
        .buttonStyle(HomeCapsuleButtonStyle())
        .disabled(!availability.isEnabled || model.storageError != nil)
        .accessibilityIdentifier("startOfDayButton")
    }

    private func startChip(now: Date) -> some View {
        doneChip(title: "Start at", date: model.dayStart, now: now)
    }

    /// Read-only chips: Start at, End at.
    private func doneChip(title: String, date: Date?, now: Date) -> some View {
        HomeCapsuleLabel(symbol: "checkmark.circle.fill", title: title,
                         subtitle: date.map { HomeTimeline.clockLabel($0, relativeTo: now) } ?? "?",
                         style: .done)
            .accessibilityElement(children: .combine)
    }

    private func nextRestCard(now: Date) -> some View {
        // Only 11 h at 3 of 3 without a confirmed split (R-D05; decisions 4–5, 30.10.2026).
        let items = HomeTimeline.shownDailyRestMilestoneHours(model.dutyLimitAvailability).map { hours in
            ("After \(hours)h rest", HomeTimeline.adding(hours: hours, to: now))
        }
        return HomeSecondaryCard(symbol: "bed.double.fill", title: "Next rest after close this day",
                                 count: items.count) { index in
            HomeValueColumn(label: items[index].0,
                            value: HomeTimeline.clockLabel(items[index].1, relativeTo: now),
                            valueSymbol: "clock")
                .accessibilityElement(children: .combine)
        }
    }

    /// Day started, Driving and Day closed open the matching sheet to correct the value.
    private func summaryCard(now: Date) -> some View {
        let items = [
            HomeSummaryItem(symbol: "play.circle", label: "Day started",
                            value: model.dayStart.map { HomeTimeline.clockLabel($0, relativeTo: now) } ?? "?",
                            detail: ShiftPlaceLine(place: model.dayStartPlace, recordedAt: model.dayStart),
                            identifier: "summaryDayStarted") { present(.editDayStart) },
            HomeSummaryItem(symbol: "steeringwheel", label: "Driving",
                            value: HomeTimeline.drivingLabel(minutes: model.drivingMinutes),
                            identifier: "summaryDriving") { present(.driving) },
            HomeSummaryItem(symbol: "stop.circle", label: "Day closed",
                            value: model.dayEnd.map { HomeTimeline.clockLabel($0, relativeTo: now) } ?? "?",
                            detail: ShiftPlaceLine(place: model.dayEndPlace, recordedAt: model.dayEnd),
                            identifier: "summaryDayClosed") { present(.editDayEnd) },
        ]
        return HomeSecondaryCard(symbol: "info.circle.fill",
                                 title: displayedRestKind(now: now) == .weekly ? "Last Shift Summary" : "Today’s summary",
                                 count: items.count) { index in
            let item = items[index]
            Button(action: item.action) {
                HomeValueColumn(symbol: item.symbol, label: item.label, value: item.value, detail: item.detail)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.storageError != nil)
            .accessibilityIdentifier(item.identifier)
            .accessibilityHint("Edit")
        }
    }

    /// The rest kind Home shows; Start of day keeps using the stored kind's milestone.
    private func displayedRestKind(now: Date) -> RestKind {
        guard let restStart = model.currentRestStart else { return model.restKind }
        return HomeTimeline.displayedRestKind(stored: model.restKind, restStart: restStart, now: now)
    }

    // MARK: - Earlier days

    private static func isHorizontalSwipe(_ translation: CGSize) -> Bool {
        abs(translation.width) > 30 && abs(translation.width) > abs(translation.height) * 1.5
    }

    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .updating($isSwiping) { drag, state, _ in
                state = Self.isHorizontalSwipe(drag.translation)
            }
            .onEnded { drag in
                // Horizontal, deliberate swipes only; vertical scrolling and open sheets are untouched.
                guard Self.isHorizontalSwipe(drag.translation) else { return }
                swipeEndedAt = Date()
                guard sheet == nil, !showDrivingAlert, abs(drag.translation.width) > 60 else { return }
                // Finger moving right opens the previous day, left goes toward today (as in iOS Calendar).
                let towardPast = drag.translation.width > 0
                if towardPast, daysBack == DayHistory.maxDaysBack {
                    showLimitHintOnce()
                } else {
                    step(to: daysBack + (towardPast ? 1 : -1))
                }
            }
    }

    /// Opens a sheet from a tap, unless the touch was a swipe.
    private func present(_ next: HomeSheet) {
        let justSwiped = swipeEndedAt.map { Date().timeIntervalSince($0) < 0.4 } ?? false
        guard !isSwiping, !justSwiped else { return }
        sheet = next
    }

    private func step(to target: Int) {
        let next = min(max(target, 0), DayHistory.maxDaysBack)
        guard next != daysBack else { return }
        slideEdge = next > daysBack ? .leading : .trailing
        withAnimation { daysBack = next }
    }

    /// Day changes slide in the swipe direction; with Reduce Motion they cross-fade instead.
    private var dayTransition: AnyTransition {
        reduceMotion ? .opacity : .push(from: slideEdge)
    }

    private static let limitHintText = "Older days are in History."

    /// A swipe past the oldest day: show the hint (again, if it was dismissed).
    private func showLimitHintOnce() {
        limitHintToken += 1
        withAnimation { showLimitHint = true }
        AccessibilityNotification.Announcement(Self.limitHintText).post()
    }

    private func dismissLimitHint() {
        withAnimation { showLimitHint = false }
    }

    @ViewBuilder
    private func pastDayContent(now: Date) -> some View {
        let day = DayHistory.day(daysBack: daysBack, from: now)
        let record = model.dayRecord(on: day)
        // The count as it stood at the end of that day (owner decision 5).
        let used = model.reducedRests(endOf: day, now: now)
        if tab.wrappedValue == .rest {
            restTakenWidget(day: day, rest: model.restTaken(after: record, now: now), reducedRestsUsed: used)
        } else {
            pastWorkWidget(day: day, record: record, now: now, reducedRestsUsed: used)
        }
        pastSummaryCard(day: day, record: record, now: now)
    }

    private func pastWorkWidget(day: Date, record: DutyPeriod?, now: Date, reducedRestsUsed: Int?) -> some View {
        let start = record?.start
        let end = record?.end
        let elapsed = start.flatMap { start in end.map { HomeTimeline.elapsedSeconds(from: start, to: $0) } }
        let subtitle = start.map { "\(HomeTimeline.dateLabel($0)) · Started \(HomeTimeline.clockLabel($0, relativeTo: $0))" }
            ?? HomeTimeline.dateLabel(day)
        return workWidget(start: start, elapsed: elapsed, instant: end ?? now, subtitle: subtitle,
                          isRestEnabled: true, labelsRelativeTo: day, placeholder: "?",
                          limitHours: HomeTimeline.pastDutyLimitHours(seconds: elapsed), reducedRestsUsed: reducedRestsUsed)
    }

    /// The Rest card layout for a past day: time taken after the shift, without 9/11/24/45 h markers.
    private func restTakenWidget(day: Date, rest: RestTaken?, reducedRestsUsed: Int?) -> some View {
        let placeholder = "?"
        return HomeMainWidget(
            icon: "HomeRestIcon", iconSize: CGSize(width: 40, height: 27),
            title: "Rest Taken",
            subtitle: rest.map { "Closed \(HomeTimeline.dateLabel($0.start)) · \(HomeTimeline.clockLabel($0.start, relativeTo: $0.start))" }
                ?? HomeTimeline.dateLabel(day),
            accent: Color.tachoTextOnLight, tab: tab, isRestEnabled: true,
            gauge: GaugeProgressView(
                limit: HomeTimeline.restTakenLabel(rest),
                value: rest.map { HomeTimeline.clockDuration(seconds: $0.seconds) } ?? placeholder,
                progress: HomeTimeline.restTakenFill(seconds: rest?.seconds), tint: .tachoBlue,
                countIcon: .bed, reducedRestsUsed: reducedRestsUsed),
            limits: [
                HomeLimit(label: "Rest started",
                          value: rest.map { HomeTimeline.clockLabel($0.start, relativeTo: day) } ?? placeholder),
                HomeLimit(label: "Rest ended",
                          value: rest.map { $0.end.map { HomeTimeline.clockLabel($0, relativeTo: day) } ?? "Running" }
                              ?? placeholder),
            ])
    }

    /// One line under the summary when a rest covers the whole day; a tap opens the day the rest
    /// started when the swipe can reach it, otherwise it is plain text.
    private func restCoverFooter(_ note: RestCoverNote, now: Date) -> AnyView {
        let text = Text("No shift this day \u{2014} you were resting since \(HomeTimeline.dayAndTime(note.restStart)).")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.tachoTextOnLight)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        guard let target = DayHistory.daysBack(of: note.restStart, from: now) else {
            return AnyView(text.accessibilityIdentifier("restCoverNote"))
        }
        return AnyView(
            Button { step(to: target) } label: { text.frame(minHeight: 44).contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityHint("Opens that day")
                .accessibilityIdentifier("restCoverNote")
        )
    }

    /// Day started, Driving and Day closed of an earlier day; empty values show "?".
    private func pastSummaryCard(day: Date, record: DutyPeriod?, now: Date) -> some View {
        let items = [
            HomeSummaryItem(symbol: "play.circle", label: "Day started",
                            value: record?.start.map { HomeTimeline.clockLabel($0, relativeTo: day) } ?? "?",
                            detail: ShiftPlaceLine(place: record?.startPlace, recordedAt: record?.start),
                            identifier: "summaryDayStarted") { present(.pastDayStart) },
            HomeSummaryItem(symbol: "steeringwheel", label: "Driving",
                            value: HomeTimeline.drivingLabel(minutes: record?.drivingMinutes),
                            identifier: "summaryDriving") { present(.pastDriving) },
            HomeSummaryItem(symbol: "stop.circle", label: "Day closed",
                            value: record?.end.map { HomeTimeline.clockLabel($0, relativeTo: day) } ?? "?",
                            detail: ShiftPlaceLine(place: record?.endPlace, recordedAt: record?.end),
                            identifier: "summaryDayClosed") { present(.pastDayEnd) },
        ]
        let note = model.restCoverNote(onDay: day, now: now)
        return HomeSecondaryCard(symbol: "info.circle.fill", title: "Day summary", count: items.count,
                                 footer: note.map { restCoverFooter($0, now: now) }) { index in
            let item = items[index]
            Button(action: item.action) {
                HomeValueColumn(symbol: item.symbol, label: item.label, value: item.value, detail: item.detail)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.storageError != nil)
            .accessibilityIdentifier(item.identifier)
            .accessibilityHint("Edit")
        }
        // The note slides in and out with the system animation when the day gains or loses it.
        .animation(.default, value: note)
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .startShift:
            // A Resume is a start too (decision 4, 13.11.2026): the same sheet with the country.
            TimeEntrySheet(kind: .shiftStart, initialDate: Date(),
                           check: { model.checkStartShift(at: $0, now: Date()) },
                           warning: overLimitLine(currentShift: { $0.startShift(at: $1, now: Date()) }),
                           country: newEventCountry,
                           onConfirm: { model.startShift(at: $0, now: Date(), place: $1); dismissSheet() },
                           onCancel: dismissSheet)
        case .editDayStart:
            TimeEntrySheet(kind: .shiftStart, initialDate: model.dayStart ?? Date(),
                           check: { model.checkEditDayStart($0, now: Date()) },
                           warning: overLimitLine(currentShift: { $0.editDayStart($1, now: Date()) }),
                           country: editCountry(model.dayStartPlace),
                           onConfirm: { model.editDayStart($0, now: Date(), place: $1); dismissSheet() },
                           onCancel: dismissSheet)
        case .closeShift:
            TimeEntrySheet(kind: .restStart, initialDate: Date(),
                           check: { model.checkCloseShift(at: $0, now: Date()) },
                           warning: overLimitLine(currentShift: { $0.closeShift(at: $1, now: Date()) }),
                           country: newEventCountry,
                           onConfirm: { date, place in
                               model.closeShift(at: date, now: Date(), place: place)
                               drivingAlertPending = model.isResting
                               dismissSheet()
                           },
                           onCancel: dismissSheet)
        case .editDayEnd:
            TimeEntrySheet(kind: .restStart, initialDate: model.dayEnd ?? Date(),
                           check: { model.checkEditDayEnd($0, now: Date()) },
                           warning: overLimitLine(currentShift: { $0.editDayEnd($1, now: Date()) }),
                           country: editCountry(model.dayEndPlace),
                           onConfirm: { model.editDayEnd($0, now: Date(), place: $1); dismissSheet() },
                           onCancel: dismissSheet)
        case .driving:
            DailyDrivingSheet(initialMinutes: model.drivingMinutes,
                              onConfirm: { model.setDrivingMinutes($0); dismissSheet() },
                              onCancel: dismissSheet)
        case .pastDayStart:
            let (day, now) = (viewedDay, Date())
            let record = model.dayRecord(on: day)
            TimeEntrySheet(kind: .shiftStart, initialDate: record?.start ?? DayHistory.combine(day: day, timeOf: now),
                           range: DayHistory.range(of: day),
                           check: { model.checkSetStart($0, onDay: day, now: Date()) },
                           warning: overLimitLine(day: day, change: { $0.setStart($1, onDay: day, now: Date()) }),
                           country: editCountry(record?.startPlace),
                           onConfirm: { model.setStart($0, onDay: day, now: Date(), place: $1); dismissSheet() },
                           onCancel: dismissSheet)
        case .pastDayEnd:
            let (day, now) = (viewedDay, Date())
            let record = model.dayRecord(on: day)
            let floor = record?.start ?? day
            TimeEntrySheet(kind: .restStart, initialDate: record?.end ?? DayHistory.combine(day: day, timeOf: now),
                           range: floor...max(floor, now),
                           check: { model.checkSetEnd($0, onDay: day, now: Date()) },
                           warning: overLimitLine(day: day, change: { $0.setEnd($1, onDay: day, now: Date()) }),
                           country: editCountry(record?.endPlace),
                           onConfirm: { model.setEnd($0, onDay: day, now: Date(), place: $1); dismissSheet() },
                           onCancel: dismissSheet)
        case .pastDriving:
            let day = viewedDay
            DailyDrivingSheet(initialMinutes: model.dayRecord(on: day)?.drivingMinutes,
                              onConfirm: { model.setDriving(minutes: $0, onDay: day); dismissSheet() },
                              onCancel: dismissSheet)
        case .violation:
            ViolationSheet(model: model, key: ViolationKey(periodID: model.dutyID, kind: .dutyLimit), style: .home,
                           onClose: dismissSheet)
        }
    }

    /// Start and Close: found from the location, the last country meanwhile; required (decision 2, 13.11.2026).
    private var newEventCountry: CountryEntry {
        CountryEntry(initial: .newEvent(lastPlace: model.lastPlace), recents: model.recentCountries(),
                     locator: locator, required: true)
    }

    /// Editing a start or close: the stored country, changeable; older records may stay without one.
    private func editCountry(_ place: ShiftPlace?) -> CountryEntry {
        CountryEntry(initial: .editing(place), recents: model.recentCountries(), locator: nil, required: false)
    }

    /// Decision 14: the red line when the entered time would push the current shift past its limit.
    private func overLimitLine(currentShift change: @escaping (DayLogModel, Date) -> Void) -> (Date) -> String? {
        { date in
            DayLogModel.overLimitLine(model.dutyViolation(previewing: { change($0, date) }, periodID: { $0.dutyID },
                                                          now: Date()))
        }
    }

    /// Decision 14 for an earlier day: the shift shown for that day after the change.
    private func overLimitLine(day: Date, change: @escaping (DayLogModel, Date) -> Void) -> (Date) -> String? {
        { date in
            DayLogModel.overLimitLine(model.dutyViolation(previewing: { change($0, date) },
                                                          periodID: { $0.historyRecord(on: day)?.id }, now: Date()))
        }
    }

    private var viewedDay: Date { DayHistory.day(daysBack: daysBack, from: Date()) }

    private func dismissSheet() {
        sheet = nil
    }

    /// The driving reminder follows the closed Rest start sheet (frame 06).
    private func presentPendingDrivingAlert() {
        guard drivingAlertPending else { return }
        drivingAlertPending = false
        showDrivingAlert = true
    }
}

/// Which limit alerts were already shown, so each appears once per shift and limit, also across relaunches.
enum LimitAlertLog {
    /// Decision 12: 15 min before the applicable limit.
    static let leadTime: TimeInterval = 15 * 60
    private static let key = "limitAlertsShown"

    /// Records `id`; false when it was already shown.
    @discardableResult
    static func markShown(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        var shown = defaults.stringArray(forKey: key) ?? []
        guard !shown.contains(id) else { return false }
        shown.append(id)
        defaults.set(Array(shown.suffix(40)), forKey: key)
        return true
    }
}

/// Small rounded label shown after a swipe past the oldest reachable day.
private struct LimitHint: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.tachoTextOnDark)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            // Same dark fill as the Today button, so the text keeps its contrast over the photo.
            .background(Color.tachoTextOnLight, in: Capsule())
            .accessibilityIdentifier("historyLimitHint")
    }
}

#Preview {
    DashboardView(model: DayLogModel())
}
