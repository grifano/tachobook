//
//  DashboardView.swift
//  TachoBook
//

import SwiftUI

public enum ActiveFlowSheet: Identifiable {
    case dayStart
    case driving
    case dayEnd
    case daySummary

    public var id: Int {
        hashValue
    }
}

public struct DashboardView: View {
    @State public var model: DayLogModel
    @State private var activeSheet: ActiveFlowSheet? = nil
    @State private var confirmNewShift = false
    @State private var confirmCloseShift = false

    public init(model: DayLogModel = DayLogModel.dashboardModel()) {
        self._model = State(initialValue: model)
    }

    public var body: some View {
        ZStack {
            // Main Content
            VStack(spacing: 0) {
                // Header
                DashboardHeaderView(date: model.selectedDate)
                    .padding(.top, 8)

                // Scrollable Dashboard Area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. Today's Limits Card
                        limitsCard
                        if model.isResting { restControls }

                        if let error = model.storageError {
                            Text(error).foregroundStyle(.white)
                        }

                        // 2. Day Log Card
                        dayLogCard

                        // 3. Action Button (Close day / Day summary)
                        actionButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    DashboardTabBarView()
                        .padding(.bottom, 8)
                }
            }

            // Dimming Overlay and Modal Presentation
            if let sheet = activeSheet {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            activeSheet = nil
                        }
                    }

                VStack {
                    Spacer()
                    switch sheet {
                    case .dayStart:
                        DayStartSheet(
                            selectedDate: Binding(
                                get: {
                                    model.dayStart ?? (ProcessInfo.processInfo.arguments.contains("-sampleData") ? DayLogModel.defaultReferenceDate() : Date())
                                },
                                set: { _ in }
                            ),
                            onConfirm: { date in
                                model.setDayStart(date)
                                withAnimation { activeSheet = nil }
                            },
                            onCancel: {
                                withAnimation { activeSheet = nil }
                            }
                        )
                        .transition(.move(edge: .bottom))

                    case .driving:
                        DailyDrivingSheet(
                            initialMinutes: model.drivingMinutes ?? 570,
                            onConfirm: { minutes in
                                model.setDrivingMinutes(minutes)
                                withAnimation { activeSheet = nil }
                            },
                            onCancel: {
                                withAnimation { activeSheet = nil }
                            }
                        )
                        .transition(.move(edge: .bottom))

                    case .dayEnd:
                        DayEndSheet(
                            selectedDate: Binding(
                                get: {
                                    model.dayEnd ?? (ProcessInfo.processInfo.arguments.contains("-sampleData") ? DayLogModel.defaultDayEndReferenceDate() : Date())
                                },
                                set: { _ in }
                            ),
                            onConfirm: { date in
                                model.setDayEnd(date)
                                withAnimation { activeSheet = nil }
                            },
                            onCancel: {
                                withAnimation { activeSheet = nil }
                            }
                        )
                        .transition(.move(edge: .bottom))

                    case .daySummary:
                        DaySummaryView(
                            model: model,
                            onClose: {
                                model.closeDay()
                                withAnimation { activeSheet = nil }
                            },
                            onEdit: { type in
                                withAnimation {
                                    switch type {
                                    case .dayStart: activeSheet = .dayStart
                                    case .driving: activeSheet = .driving
                                    case .dayEnd: activeSheet = .dayEnd
                                    }
                                }
                            },
                            onDelete: { type in
                                model.deleteEntry(type)
                            }
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .confirmationDialog("Close shift and start rest?", isPresented: $confirmCloseShift, titleVisibility: .visible) {
            Button("Close shift") {
                model.closeShift(at: model.dayEnd ?? Date())
            }
        } message: {
            Text(model.drivingMinutes == nil ? "Did you remember to enter today's total driving time? You can add it later in Day summary." : "Rest starts from the logged end time. You can resume this duty period after a short rest.")
        }
        .confirmationDialog("Start a new duty period?", isPresented: $confirmNewShift, titleVisibility: .visible) {
            Button("Daily rest confirmed — start new shift") {
                model.startNewShift(at: Date(), dailyRestConfirmed: true)
            }
        } message: {
            Text("Confirm that this uninterrupted rest satisfies your daily-rest requirement. Duration alone does not establish eligibility; reduction counts, split rest and exceptions are not evaluated here.")
        }
        .background {
            ZStack {
                Color.tachoDark
                GeometryReader { geo in
                    Image("DashboardBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeSheet)
    }

    // MARK: - Subviews

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today’s Limits")
                .font(.system(.footnote, weight: .semibold))
                .foregroundColor(.tachoDark)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 32) {
                    GaugeProgressView(
                        title: "Shift elapsed",
                        value: model.shiftDurationString(at: context.date),
                        progress: min(1, Double(model.shiftElapsedSeconds(at: context.date) ?? 0) / (15 * 3600)),
                        secondaryValue: model.isShiftOpen ? model.shiftSecondsString(at: context.date) : nil
                    )
                    GaugeProgressView(
                        title: "Rest Time",
                        value: DayLogModel.durationString(seconds: model.restElapsedSeconds(at: context.date)),
                        progress: min(1, Double(model.restElapsedSeconds(at: context.date)) / (11 * 3600)),
                        progressColor: .tachoTrackGray
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: TachoTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TachoTheme.cardRadius)
                .stroke(Color.tachoCardBorder, lineWidth: 2)
        )
    }

    private var dayLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day log")
                .font(.system(.footnote, weight: .semibold))
                .foregroundColor(.tachoDark)

            VStack(spacing: 8) {
                // Row 1: Day start
                logRow(
                    isLogged: model.dayStart != nil,
                    title: "Day start",
                    value: model.dayStartDisplayString,
                    identifier: "editDayStartButton",
                    isEditable: model.restSegments.isEmpty,
                    onEdit: { activeSheet = .dayStart }
                )

                Divider()
                    .background(Color.tachoSeparator)

                // Row 2: Driving log
                logRow(
                    isLogged: model.drivingMinutes != nil,
                    title: "Driving log",
                    value: model.drivingMinutes != nil ? model.drivingDisplayString : "-",
                    identifier: "editDrivingButton",
                    onEdit: { activeSheet = .driving }
                )

                Divider()
                    .background(Color.tachoSeparator)

                // Row 3: Day end
                logRow(
                    isLogged: model.dayEnd != nil,
                    title: "Day end",
                    value: model.dayEndDisplayString,
                    identifier: "editDayEndButton",
                    onEdit: { activeSheet = .dayEnd }
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: TachoTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TachoTheme.cardRadius)
                .stroke(Color.tachoCardBorder, lineWidth: 2)
        )
    }

    private func logRow(
        isLogged: Bool,
        title: String,
        value: String,
        identifier: String = "",
        isEditable: Bool = true,
        onEdit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            // Leading status & title
            HStack(spacing: 8) {
                if isLogged {
                    ZStack {
                        Circle()
                            .fill(Color.tachoGreen)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(.caption, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(title)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundColor(.tachoDark)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Trailing actions
            HStack(spacing: 12) {
                Text(value)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundColor(isLogged ? .tachoDark : .tachoSecondary)
                    .lineLimit(1)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.tachoOrange)
                        .frame(width: 50, height: 50)
                        .background(Color.tachoGray)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier(identifier)
                .disabled(!isEditable)
            }
        }
        .frame(minHeight: 52)
    }

    private var restControls: some View {
        VStack(spacing: 12) {
            Text("Rest in progress · eligibility not evaluated")
                .font(.caption).foregroundStyle(Color.tachoDark)
            if let nine = model.restMilestone(hours: 9), let eleven = model.restMilestone(hours: 11) {
                Text("9h: \(nine.formatted(date: .abbreviated, time: .shortened)) · 11h: \(eleven.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(Color.tachoDark)
            }
            Button("Resume shift") { model.resumeShift(at: Date()) }
                .buttonStyle(.borderedProminent).tint(.tachoOrange)
                .accessibilityIdentifier("resumeShiftButton")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if model.restElapsedSeconds(at: context.date) >= 9 * 3600 {
                    Button("Start new shift…") { confirmNewShift = true }
                        .buttonStyle(.bordered).tint(.tachoOrange)
                        .accessibilityIdentifier("newShiftButton")
                }
            }
            Text("Records continuation of the same shift. Rest qualification requires review.")
                .font(.caption).foregroundStyle(Color.tachoDark)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: TachoTheme.cardRadius))
    }


    private var actionButton: some View {
        Group {
            if model.isDayClosed {

                // Completed day: "Day summary" button reopens summary
                Button(action: {
                    activeSheet = .daySummary
                }) {
                    Text("Day summary")
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.tachoOrange)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("daySummaryButton")
            } else {
                // Not completed yet: "Close day" button
                Button(action: {
                    confirmCloseShift = true
                }) {
                    Text("Close day")
                        .font(.body)
                        .foregroundColor(model.isShiftOpen ? .white : Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(model.isShiftOpen ? Color.tachoOrange : Color.tachoGray)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("closeDayButton")
                .disabled(!model.isShiftOpen || model.storageError != nil)
            }
        }
    }
}
