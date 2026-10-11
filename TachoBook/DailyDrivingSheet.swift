//
//  DailyDrivingSheet.swift
//  TachoBook
//

import SwiftUI

public struct DailyDrivingSheet: View {
    @ScaledMetric(relativeTo: .largeTitle) private var durationSize: CGFloat = 64
    public var initialMinutes: Int?
    public var onConfirm: (Int) -> Void
    public var onCancel: () -> Void

    @State private var hours: Int = 9
    @State private var minutes: Int = 30
    @State private var inputBuffer: String = "930" // represents 9h30

    public init(
        initialMinutes: Int? = 570,
        onConfirm: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialMinutes = initialMinutes
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    private var displayDurationString: String {
        let totalMinutes = computedMinutes
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%dh%02d", h, m)
    }

    private var computedMinutes: Int {
        if inputBuffer.isEmpty {
            return 0
        }
        if inputBuffer.count <= 2 {
            let m = Int(inputBuffer) ?? 0
            return m
        } else {
            let mString = String(inputBuffer.suffix(2))
            let hString = String(inputBuffer.dropLast(2))
            let h = Int(hString) ?? 0
            let m = Int(mString) ?? 0
            return (h * 60) + min(59, m)
        }
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
                    Text("Daily driving")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.tachoDark)
                    Text("How long did you drive today?")
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(Color(red: 114/255, green: 114/255, blue: 114/255))
                }

                Spacer()

                Button(action: {
                    onConfirm(computedMinutes)
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.tachoOrange)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("confirmDrivingButton")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer(minLength: 12)

            // Symbol
            ZStack {
                Circle()
                    .fill(Color.tachoGray)
                    .frame(width: 68, height: 68)

                TachoDrivingSymbol(color: Color.tachoDark.opacity(0.6))
                    .frame(width: 26, height: 26)
            }
            .padding(.bottom, 12)

            // Large duration display (64pt bold)
            Text(displayDurationString)
                .font(.system(size: durationSize, weight: .bold))
                .foregroundColor(.tachoDark)
                .tracking(0.4)

            Spacer(minLength: 12)

            // Numeric Keypad
            VStack(spacing: 6) {
                // Row 1
                HStack(spacing: 6) {
                    KeypadButton(title: "1") { handleDigit("1") }
                    KeypadButton(title: "2") { handleDigit("2") }
                    KeypadButton(title: "3") { handleDigit("3") }
                }
                // Row 2
                HStack(spacing: 6) {
                    KeypadButton(title: "4") { handleDigit("4") }
                    KeypadButton(title: "5") { handleDigit("5") }
                    KeypadButton(title: "6") { handleDigit("6") }
                }
                // Row 3
                HStack(spacing: 6) {
                    KeypadButton(title: "7") { handleDigit("7") }
                    KeypadButton(title: "8") { handleDigit("8") }
                    KeypadButton(title: "9") { handleDigit("9") }
                }
                // Row 4
                HStack(spacing: 6) {
                    Color.clear
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)

                    KeypadButton(title: "0") { handleDigit("0") }

                    Button(action: handleDelete) {
                        Image(systemName: "delete.backward")
                            .font(.title3)
                            .foregroundColor(Color(red: 89/255, green: 89/255, blue: 89/255))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8.5))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 24)
            .background(
                Color(red: 230/255, green: 233/255, blue: 237/255)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            )
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 38, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 38, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 25, y: -5)
    }

    private func handleDigit(_ digit: String) {
        if inputBuffer == "930" && digit != "9" {
            // First keystroke replaces default unless editing
            inputBuffer = digit
        } else if inputBuffer.count < 4 {
            inputBuffer.append(digit)
        }
    }

    private func handleDelete() {
        if !inputBuffer.isEmpty {
            inputBuffer.removeLast()
        }
    }
}

struct KeypadButton: View {
    @ScaledMetric(relativeTo: .title2) private var digitSize: CGFloat = 23
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: digitSize))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8.5))
        }
    }
}
