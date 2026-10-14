//
//  DaySummaryView.swift
//  TachoBook
//

import SwiftUI

public struct DaySummaryView: View {
    public var model: DayLogModel
    public var onClose: () -> Void
    public var onEdit: (LogEntryType) -> Void
    public var onDelete: (LogEntryType) -> Void

    @State private var swipedRow: LogEntryType? = nil
    @State private var dragOffsets: [LogEntryType: CGFloat] = [:]

    public init(
        model: DayLogModel,
        onClose: @escaping () -> Void,
        onEdit: @escaping (LogEntryType) -> Void,
        onDelete: @escaping (LogEntryType) -> Void
    ) {
        self.model = model
        self.onClose = onClose
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Grabber
            RoundedRectangle(cornerRadius: 100)
                .fill(Color.tachoOrange)
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Header Controls
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.tachoDark)
                        .frame(width: 44, height: 44)
                        .background(Color.tachoGray)
                        .clipShape(Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Day summary")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.tachoDark)
                    Text("\(model.selectedDate.formatted(date: .abbreviated, time: .omitted)) · Not evaluated")
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(Color(red: 114/255, green: 114/255, blue: 114/255))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "checkmark")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.tachoOrange)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Shift List Items
                    VStack(spacing: 8) {
                        // Row 1: Day Start
                        if model.dayStart != nil {
                            summaryRow(
                                type: .dayStart,
                                title: "Day start",
                                subtitle: model.dayStartFullDisplayString,
                                imageName: "SummaryStart",
                                fallbackSymbol: AnyView(ShiftStartSymbol(color: .white))
                            )
                        }

                        // Row 2: Day End
                        if model.dayEnd != nil {
                            summaryRow(
                                type: .dayEnd,
                                title: "Day end",
                                subtitle: model.dayEndFullDisplayString,
                                imageName: "SummaryEnd",
                                fallbackSymbol: AnyView(ShiftEndSymbol(color: .white)),
                                showRestCount: true
                            )
                        }

                        // Row 3: Daily Driving
                        if model.drivingMinutes != nil {
                            summaryRow(
                                type: .driving,
                                title: "Daily driving",
                                subtitle: model.drivingDisplayString,
                                imageName: "SummaryDriving",
                                fallbackSymbol: AnyView(TachoDrivingSymbol(color: .white)),
                                showDrivingCount: true
                            )
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16)

                    ForEach(model.restSegments) { rest in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rest.end == nil ? "Rest in progress" : "Rest segment")
                                .font(.subheadline.weight(.semibold))
                            Text("\(rest.start.formatted(date: .abbreviated, time: .shortened)) → \(rest.end.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "ongoing")")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.tachoDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // Shift duration includes intermediate rests.
                    GaugeProgressView(
                        title: "Shift elapsed",
                        value: model.workingTimeString,
                        progress: model.workingFraction,
                        progressColor: Color.tachoOrange
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    // Violation Status
                    VStack(spacing: 4) {
                        Image(systemName: "questionmark.shield")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundColor(.tachoBlue)
                        Text("Not evaluated")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundColor(.tachoBlue)
                    }
                    .padding(.bottom, 16)
                }
            }

            // Close Button
            Button(action: onClose) {
                Text("Close")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.tachoOrange)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("closeSummaryButton")
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 38, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 38, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 25, y: -5)
    }

    @ViewBuilder
    private func summaryRow(
        type: LogEntryType,
        title: String,
        subtitle: String,
        imageName: String,
        fallbackSymbol: AnyView,
        showRestCount: Bool = false,
        showDrivingCount: Bool = false
    ) -> some View {
        let offset = dragOffsets[type] ?? (swipedRow == type ? -120 : 0)

        ZStack(alignment: .trailing) {
            // Action Buttons underneath (Edit & Delete matching Screen 09)
            HStack(spacing: 10) {
                // Edit Button
                VStack(spacing: 4) {
                    Button(action: {
                        onEdit(type)
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.tachoGreen)
                            .clipShape(Circle())
                    }
                    .disabled(type == .dayStart && !model.restSegments.isEmpty)
                    Text("Edit")
                        .font(.system(.footnote, weight: .medium))
                        .foregroundColor(Color.tachoSecondary)
                }

                // Delete Button
                VStack(spacing: 4) {
                    Button(action: {
                        withAnimation {
                            onDelete(type)
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.tachoRed)
                            .clipShape(Circle())
                    }
                    .disabled(type != .driving && !model.restSegments.isEmpty)
                    Text("Delete")
                        .font(.system(.footnote, weight: .medium))
                        .foregroundColor(Color.tachoSecondary)
                }
            }
            .padding(.trailing, 4)
            .opacity(abs(offset) > 5 ? 1 : 0)

            // Front Row Content
            HStack(spacing: 12) {
                // Round Leading Image
                ZStack {
                    if let uiImage = UIImage(named: imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 52, height: 52)
                    } else {
                        Circle()
                            .fill(Color.tachoGreen)
                            .frame(width: 52, height: 52)
                        fallbackSymbol
                            .frame(width: 22, height: 22)
                    }
                }

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.tachoDark)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.tachoSecondary)
                }

                Spacer()

                // Optional Counts
                if showRestCount {
                    Image("IconRest")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.tachoSecondary)
                }

                if showDrivingCount {
                    Image("IconDrive")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.tachoSecondary)
                }

                // Detail disclosure
                HStack(spacing: 4) {
                    Text("Detail")
                        .font(.subheadline)
                        .foregroundColor(.tachoSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundColor(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            dragOffsets[type] = max(-130, value.translation.width)
                        } else {
                            dragOffsets[type] = min(0, (swipedRow == type ? -120 : 0) + value.translation.width)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if value.translation.width < -50 {
                                swipedRow = type
                                dragOffsets[type] = -120
                            } else {
                                swipedRow = nil
                                dragOffsets[type] = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if swipedRow == type {
                    withAnimation {
                        swipedRow = nil
                        dragOffsets[type] = 0
                    }
                }
            }
        }
        .frame(minHeight: 68)
    }
}
