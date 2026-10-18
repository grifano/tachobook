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

        var id: String { rawValue }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State public var model: DayLogModel
    @State private var sheet: HomeSheet?
    @State private var tabOverride: HomeTab?
    @State private var showDrivingAlert = false
    @State private var drivingAlertPending = false

    public init(model: DayLogModel = DayLogModel.dashboardModel()) {
        self._model = State(initialValue: model)
    }

    /// The default tab follows the shift state; the toggle only overrides the view.
    private var tab: Binding<HomeTab> {
        let defaultTab: HomeTab = model.isResting ? .rest : .work
        return Binding(
            get: { tabOverride ?? defaultTab },
            set: { tabOverride = $0 == defaultTab ? nil : $0 }
        )
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            VStack(spacing: 0) {
                DashboardHeaderView(date: now)
                ScrollView {
                    VStack(spacing: 20) {
                        content(now: now)
                        if let error = model.storageError {
                            Text(error).font(.footnote).foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DashboardTabBarView()
                .padding(.bottom, 8)
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
        .onChange(of: model.isResting) { tabOverride = nil }
        .sheet(item: $sheet, onDismiss: presentPendingDrivingAlert) { sheet in
            sheetContent(sheet)
        }
        .alert("Shift closed", isPresented: $showDrivingAlert) {
            Button("Later", role: .cancel) {}
            Button("Add time") { sheet = .driving }
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
                Button { sheet = .closeShift } label: {
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
        let elapsed = model.shiftElapsedSeconds(at: now) ?? 0
        // A frozen shift is judged at its close time, a running one at now.
        let instant = model.currentRestStart ?? now
        let markers = start.map { HomeTimeline.dutyMarkers(shiftStart: $0) }
        let warning = start.flatMap { start in
            HomeTimeline.isDutyWarning(shiftStart: start, at: instant)
                ? HomeTimeline.remainingDuration(seconds: HomeTimeline.dutyRemainingSeconds(shiftStart: start, at: instant))
                : nil
        }
        let subtitle = start.map {
            "\(HomeTimeline.dayLabel($0, relativeTo: now)) · Started \(HomeTimeline.clockLabel($0, relativeTo: $0))"
        } ?? "Today"
        return HomeMainWidget(
            icon: "HomeWorkIcon", iconSize: CGSize(width: 40, height: 40),
            title: "Work Time", subtitle: subtitle, accent: .tachoDark,
            tab: tab, isRestEnabled: model.isResting,
            gauge: GaugeProgressView(
                limit: "\(HomeTimeline.dutyMarkerHours.second)h",
                value: HomeTimeline.clockDuration(seconds: elapsed),
                progress: Double(elapsed) / (Double(HomeTimeline.dutyMarkerHours.second) * 3600),
                tint: .tachoOrange, warning: warning),
            limits: [
                HomeLimit(label: "\(HomeTimeline.dutyMarkerHours.first)h limit end",
                          value: markers.map { HomeTimeline.clockLabel($0.first, relativeTo: now) } ?? "--:--"),
                HomeLimit(label: "\(HomeTimeline.dutyMarkerHours.second)h limit end",
                          value: markers.map { HomeTimeline.clockLabel($0.second, relativeTo: now) } ?? "--:--"),
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
                accent: TachoTheme.blueText, tab: tab, isRestEnabled: true,
                gauge: GaugeProgressView(
                    limit: "\(kind.requiredHours)h",
                    value: HomeTimeline.clockDuration(seconds: elapsed),
                    progress: Double(elapsed) / (Double(kind.requiredHours) * 3600),
                    tint: .tachoBlue),
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
        return Button { sheet = .startShift } label: {
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
                            identifier: "summaryDayStarted") { sheet = .editDayStart },
            HomeSummaryItem(symbol: "steeringwheel", label: "Driving",
                            value: HomeTimeline.drivingLabel(minutes: model.drivingMinutes),
                            identifier: "summaryDriving") { sheet = .driving },
            HomeSummaryItem(symbol: "stop.circle", label: "Day closed",
                            value: model.dayEnd.map { HomeTimeline.clockLabel($0, relativeTo: now) } ?? "?",
                            identifier: "summaryDayClosed") { sheet = .editDayEnd },
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

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .startShift:
            TimeEntrySheet(kind: .shiftStart, initialDate: Date(),
                           isValid: { model.canStartShift(at: $0, now: Date()) },
                           onConfirm: { model.startShift(at: $0, now: Date()); dismissSheet() },
                           onCancel: dismissSheet)
        case .editDayStart:
            TimeEntrySheet(kind: .shiftStart, initialDate: model.dayStart ?? Date(),
                           isValid: { model.canEditDayStart($0, now: Date()) },
                           onConfirm: { model.editDayStart($0, now: Date()); dismissSheet() },
                           onCancel: dismissSheet)
        case .closeShift:
            TimeEntrySheet(kind: .restStart, initialDate: Date(),
                           isValid: { model.canCloseShift(at: $0, now: Date()) },
                           onConfirm: { date in
                               model.closeShift(at: date, now: Date())
                               drivingAlertPending = model.isResting
                               dismissSheet()
                           },
                           onCancel: dismissSheet)
        case .editDayEnd:
            TimeEntrySheet(kind: .restStart, initialDate: model.dayEnd ?? Date(),
                           isValid: { model.canEditDayEnd($0, now: Date()) },
                           onConfirm: { model.editDayEnd($0, now: Date()); dismissSheet() },
                           onCancel: dismissSheet)
        case .driving:
            DailyDrivingSheet(initialMinutes: model.drivingMinutes,
                              onConfirm: { model.setDrivingMinutes($0); dismissSheet() },
                              onCancel: dismissSheet)
        }
    }

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

#Preview {
    DashboardView(model: DayLogModel())
}
