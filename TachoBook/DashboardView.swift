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

        var id: String { rawValue }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State public var model: DayLogModel
    @State private var sheet: HomeSheet?
    @State private var tabOverride: HomeTab?
    @State private var showDrivingAlert = false
    @State private var drivingAlertPending = false
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
        // A frozen shift is judged at its close time, a running one at now.
        return workWidget(start: start, elapsed: model.shiftElapsedSeconds(at: now) ?? 0,
                          instant: model.currentRestStart ?? now, subtitle: subtitle,
                          isRestEnabled: model.isResting, labelsRelativeTo: now,
                          reducedRestsUsed: model.workCardReducedRests(now: now))
    }

    /// Work card for any shift. `elapsed` nil shows the "--:--" placeholder instead of zeros.
    /// `reducedRestsUsed` shows the bed row once the shift's reduction is certain (past 13 h).
    private func workWidget(start: Date?, elapsed: Int?, instant: Date, subtitle: String,
                            isRestEnabled: Bool, labelsRelativeTo reference: Date,
                            placeholder: String = "--:--", reducedRestsUsed: Int? = nil) -> some View {
        let markers = start.map { HomeTimeline.dutyMarkers(shiftStart: $0) }
        let warning = start.flatMap { start in
            elapsed != nil && HomeTimeline.isDutyWarning(shiftStart: start, at: instant)
                ? HomeTimeline.remainingDuration(seconds: HomeTimeline.dutyRemainingSeconds(shiftStart: start, at: instant))
                : nil
        }
        return HomeMainWidget(
            icon: "HomeWorkIcon", iconSize: CGSize(width: 40, height: 40),
            title: "Work Time", subtitle: subtitle, accent: .tachoTextOnLight,
            tab: tab, isRestEnabled: isRestEnabled,
            gauge: GaugeProgressView(
                limit: "\(HomeTimeline.dutyMarkerHours.second)h",
                value: elapsed.map { HomeTimeline.clockDuration(seconds: $0) } ?? placeholder,
                progress: Double(elapsed ?? 0) / (Double(HomeTimeline.dutyMarkerHours.second) * 3600),
                tint: .tachoOrange, warning: warning, reducedRestsUsed: reducedRestsUsed),
            limits: [
                HomeLimit(label: "\(HomeTimeline.dutyMarkerHours.first)h limit end",
                          value: markers.map { HomeTimeline.clockLabel($0.first, relativeTo: reference) } ?? placeholder),
                HomeLimit(label: "\(HomeTimeline.dutyMarkerHours.second)h limit end",
                          value: markers.map { HomeTimeline.clockLabel($0.second, relativeTo: reference) } ?? placeholder),
            ])
    }

    @ViewBuilder
    private func restWidget(now: Date) -> some View {
        if let restStart = model.currentRestStart {
            // The card follows the displayed kind (a daily rest past 11 h shows as weekly).
            let kind = HomeTimeline.displayedRestKind(stored: model.restKind, restStart: restStart, now: now)
            let elapsed = HomeTimeline.elapsedSeconds(from: restStart, to: now)
            let milestones = HomeTimeline.restMilestones(restStart: restStart, kind: kind)
            HomeMainWidget(
                icon: "HomeRestIcon", iconSize: CGSize(width: 40, height: 27),
                title: kind == .weekly ? "Weekly Rest" : "Rest Time",
                subtitle: "Closed \(HomeTimeline.dateLabel(restStart)) · \(HomeTimeline.clockLabel(restStart, relativeTo: restStart))",
                accent: Color.tachoTextOnLight, tab: tab, isRestEnabled: true,
                gauge: GaugeProgressView(
                    limit: "\(kind.requiredHours)h",
                    value: HomeTimeline.clockDuration(seconds: elapsed),
                    progress: Double(elapsed) / (Double(kind.requiredHours) * 3600),
                    tint: .tachoBlue, reducedRestsUsed: model.reducedRestsUsed),
                limits: [
                    HomeLimit(label: "After \(kind.milestoneHours.first)h rest",
                              value: HomeTimeline.clockLabel(milestones.first, relativeTo: now)),
                    HomeLimit(label: "After \(kind.milestoneHours.second)h rest",
                              value: HomeTimeline.clockLabel(milestones.second, relativeTo: now)),
                ])
        }
    }

    private func startOfDayButton(now: Date) -> some View {
        let countdown = model.currentRestStart.flatMap {
            HomeTimeline.availabilityCountdown(restStart: $0, kind: model.restKind, now: now)
        }
        let isAvailable = countdown == nil && model.storageError == nil
        return Button { present(.startShift) } label: {
            HomeCapsuleLabel(symbol: "play.circle", title: "Start of day",
                             subtitle: countdown.map { "Available in \($0)" },
                             style: isAvailable ? .primary : .dimmed,
                             titleFont: .headline, subtitleFont: .footnote)
        }
        .buttonStyle(HomeCapsuleButtonStyle())
        .disabled(!isAvailable)
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
        let milestones = HomeTimeline.restMilestones(restStart: now, kind: .daily)
        let items = [
            ("After \(RestKind.daily.milestoneHours.first)h rest", milestones.first),
            ("After \(RestKind.daily.milestoneHours.second)h rest", milestones.second),
        ]
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
                            identifier: "summaryDayStarted") { present(.editDayStart) },
            HomeSummaryItem(symbol: "steeringwheel", label: "Driving",
                            value: HomeTimeline.drivingLabel(minutes: model.drivingMinutes),
                            identifier: "summaryDriving") { present(.driving) },
            HomeSummaryItem(symbol: "stop.circle", label: "Day closed",
                            value: model.dayEnd.map { HomeTimeline.clockLabel($0, relativeTo: now) } ?? "?",
                            identifier: "summaryDayClosed") { present(.editDayEnd) },
        ]
        return HomeSecondaryCard(symbol: "info.circle.fill",
                                 title: displayedRestKind(now: now) == .weekly ? "Last Shift Summary" : "Today’s summary",
                                 count: items.count) { index in
            let item = items[index]
            Button(action: item.action) {
                HomeValueColumn(symbol: item.symbol, label: item.label, value: item.value)
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
        if tab.wrappedValue == .rest {
            restTakenWidget(day: day, rest: model.restTaken(after: record, now: now))
        } else {
            pastWorkWidget(day: day, record: record, now: now)
        }
        pastSummaryCard(day: day, record: record, now: now)
    }

    private func pastWorkWidget(day: Date, record: DutyPeriod?, now: Date) -> some View {
        let start = record?.start
        let end = record?.end
        let elapsed = start.flatMap { start in end.map { HomeTimeline.elapsedSeconds(from: start, to: $0) } }
        let subtitle = start.map { "\(HomeTimeline.dateLabel($0)) · Started \(HomeTimeline.clockLabel($0, relativeTo: $0))" }
            ?? HomeTimeline.dateLabel(day)
        return workWidget(start: start, elapsed: elapsed, instant: end ?? now, subtitle: subtitle,
                          isRestEnabled: true, labelsRelativeTo: day, placeholder: "?")
    }

    /// The Rest card layout for a past day: time taken after the shift, without 9/11/24/45 h markers.
    private func restTakenWidget(day: Date, rest: RestTaken?) -> some View {
        let placeholder = "?"
        return HomeMainWidget(
            icon: "HomeRestIcon", iconSize: CGSize(width: 40, height: 27),
            title: "Rest Taken",
            subtitle: rest.map { "Closed \(HomeTimeline.dateLabel($0.start)) · \(HomeTimeline.clockLabel($0.start, relativeTo: $0.start))" }
                ?? HomeTimeline.dateLabel(day),
            accent: Color.tachoTextOnLight, tab: tab, isRestEnabled: true,
            gauge: GaugeProgressView(
                limit: rest?.end == nil && rest != nil ? "So far" : "Taken",
                value: rest.map { HomeTimeline.clockDuration(seconds: $0.seconds) } ?? placeholder,
                progress: 0, tint: .tachoBlue),
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
                            identifier: "summaryDayStarted") { present(.pastDayStart) },
            HomeSummaryItem(symbol: "steeringwheel", label: "Driving",
                            value: HomeTimeline.drivingLabel(minutes: record?.drivingMinutes),
                            identifier: "summaryDriving") { present(.pastDriving) },
            HomeSummaryItem(symbol: "stop.circle", label: "Day closed",
                            value: record?.end.map { HomeTimeline.clockLabel($0, relativeTo: day) } ?? "?",
                            identifier: "summaryDayClosed") { present(.pastDayEnd) },
        ]
        let note = model.restCoverNote(onDay: day, now: now)
        return HomeSecondaryCard(symbol: "info.circle.fill", title: "Day summary", count: items.count,
                                 footer: note.map { restCoverFooter($0, now: now) }) { index in
            let item = items[index]
            Button(action: item.action) {
                HomeValueColumn(symbol: item.symbol, label: item.label, value: item.value)
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
            TimeEntrySheet(kind: .shiftStart, initialDate: Date(),
                           check: { model.checkStartShift(at: $0, now: Date()) },
                           onConfirm: { model.startShift(at: $0, now: Date()); dismissSheet() },
                           onCancel: dismissSheet)
        case .editDayStart:
            TimeEntrySheet(kind: .shiftStart, initialDate: model.dayStart ?? Date(),
                           check: { model.checkEditDayStart($0, now: Date()) },
                           onConfirm: { model.editDayStart($0, now: Date()); dismissSheet() },
                           onCancel: dismissSheet)
        case .closeShift:
            TimeEntrySheet(kind: .restStart, initialDate: Date(),
                           check: { model.checkCloseShift(at: $0, now: Date()) },
                           onConfirm: { date in
                               model.closeShift(at: date, now: Date())
                               drivingAlertPending = model.isResting
                               dismissSheet()
                           },
                           onCancel: dismissSheet)
        case .editDayEnd:
            TimeEntrySheet(kind: .restStart, initialDate: model.dayEnd ?? Date(),
                           check: { model.checkEditDayEnd($0, now: Date()) },
                           onConfirm: { model.editDayEnd($0, now: Date()); dismissSheet() },
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
                           onConfirm: { model.setStart($0, onDay: day, now: Date()); dismissSheet() },
                           onCancel: dismissSheet)
        case .pastDayEnd:
            let (day, now) = (viewedDay, Date())
            let record = model.dayRecord(on: day)
            let floor = record?.start ?? day
            TimeEntrySheet(kind: .restStart, initialDate: record?.end ?? DayHistory.combine(day: day, timeOf: now),
                           range: floor...max(floor, now),
                           check: { model.checkSetEnd($0, onDay: day, now: Date()) },
                           onConfirm: { model.setEnd($0, onDay: day, now: Date()); dismissSheet() },
                           onCancel: dismissSheet)
        case .pastDriving:
            let day = viewedDay
            DailyDrivingSheet(initialMinutes: model.dayRecord(on: day)?.drivingMinutes,
                              onConfirm: { model.setDriving(minutes: $0, onDay: day); dismissSheet() },
                              onCancel: dismissSheet)
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
