//
//  DayEndSheet.swift
//  TachoBook
//

import SwiftUI

public struct DayEndSheet: View {
    @Binding var selectedDate: Date
    public var onConfirm: (Date) -> Void
    public var onCancel: () -> Void

    @State private var currentDate: Date
    @State private var showTimePicker: Bool = false

    public init(
        selectedDate: Binding<Date>,
        onConfirm: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._selectedDate = selectedDate
        self._currentDate = State(initialValue: selectedDate.wrappedValue)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    private var dateString: String {
        currentDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var timeString: String {
        currentDate.formatted(date: .omitted, time: .shortened)
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
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.tachoDark)
                        .frame(width: 44, height: 44)
                        .background(Color.tachoGray)
                        .clipShape(Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Day end")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.tachoDark)
                    Text("When did your shift end?")
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(Color(red: 114/255, green: 114/255, blue: 114/255))
                }

                Spacer()

                Button(action: {
                    onConfirm(currentDate)
                }) {
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

            Spacer(minLength: 16)

            // Symbol
            ZStack {
                Circle()
                    .fill(Color.tachoGray)
                    .frame(width: 68, height: 68)

                ShiftEndSymbol(color: Color.tachoDark.opacity(0.6))
                    .frame(width: 26, height: 26)
            }
            .padding(.bottom, 20)

            // Date and Time Pills
            HStack(spacing: 8) {
                // Date Pill
                Text(dateString)
                    .font(.body)
                    .foregroundColor(.tachoDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.tachoGray)
                    .clipShape(Capsule())

                // Time Pill
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showTimePicker.toggle()
                    }
                }) {
                    Text(timeString)
                        .font(.body)
                        .foregroundColor(.tachoDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.tachoGray)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("timePillButton")
            }
            .padding(.bottom, showTimePicker ? 8 : 20)

            if showTimePicker {
                DatePicker("", selection: $currentDate, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.wheel)
                    .environment(\.colorScheme, .light)
                    .labelsHidden()
                    .frame(height: 216)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("timePicker")
            }

            Spacer(minLength: 16)

            // Bottom Buttons
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.body)
                        .foregroundColor(.tachoDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Capsule())
                }

                Button(action: {
                    onConfirm(currentDate)
                }) {
                    Text("Confirm")
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.tachoOrange)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("confirmDayEndButton")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 38, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 38, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 25, y: -5)
    }
}
