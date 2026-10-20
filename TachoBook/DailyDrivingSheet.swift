//
//  DailyDrivingSheet.swift
//  TachoBook
//

import SwiftUI

/// Figma frame 07: total driving time for the shift, typed on a numeric keypad as h + mm.
public struct DailyDrivingSheet: View {
    @ScaledMetric(relativeTo: .largeTitle) private var durationSize: CGFloat = 64
    public var onConfirm: (Int) -> Void
    public var onCancel: () -> Void

    @State private var entry: DrivingEntry

    public init(initialMinutes: Int?, onConfirm: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _entry = State(initialValue: DrivingEntry(minutes: initialMinutes))
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetToolbar(title: "Driving time", subtitle: "How long are you driving today?",
                         canConfirm: entry.minutes != nil, onCancel: onCancel,
                         onConfirm: { entry.minutes.map(onConfirm) })
            VStack(spacing: 16) {
                SheetSymbol(image: "SheetDrivingIcon", height: 36)
                Text(entry.display)
                    .font(.system(size: durationSize, weight: .bold))
                    .tracking(0.4)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Color.tachoTextOnLight)
                    .accessibilityLabel("Driving time \(entry.display)")
                    .accessibilityIdentifier("drivingValue")
            }
            .padding(.horizontal, 16)
            .padding(.top, 38)
            Spacer(minLength: 24)
            keypad
        }
        .environment(\.colorScheme, .light)
        .presentationDetents([.height(619), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.white)
    }

    private var keypad: some View {
        VStack(spacing: 6) {
            ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { digit in
                        KeypadButton(title: digit) { entry.append(digit) }
                    }
                }
            }
            HStack(spacing: 6) {
                Color.clear.frame(maxWidth: .infinity).frame(height: 50)
                KeypadButton(title: "0") { entry.append("0") }
                Button { entry.deleteLast() } label: {
                    Image(systemName: "delete.backward")
                        .font(.title3)
                        .foregroundStyle(Color(red: 89/255, green: 89/255, blue: 89/255))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Delete")
            }
        }
        .padding(.horizontal, 7.67)
        .padding(.top, 24)
        .padding(.bottom, 42)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 27, bottomLeadingRadius: 62,
                                   bottomTrailingRadius: 62, topTrailingRadius: 27, style: .continuous)
                .fill(Color(red: 230/255, green: 233/255, blue: 237/255))
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Keypad input: the last two digits are minutes. Prefilled values are replaced by the first key.
struct DrivingEntry: Equatable {
    private(set) var digits: String
    private var replacesOnInput: Bool

    init(minutes: Int?) {
        if let minutes {
            digits = String(format: "%d%02d", minutes / 60, minutes % 60)
            replacesOnInput = true
        } else {
            digits = ""
            replacesOnInput = false
        }
    }

    /// nil while empty or when the minutes part is above 59: such values cannot be confirmed.
    var minutes: Int? {
        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        let (hours, mins) = value.quotientAndRemainder(dividingBy: 100)
        return mins < 60 ? hours * 60 + mins : nil
    }

    var display: String {
        let value = Int(digits) ?? 0
        return String(format: "%dh%02d", value / 100, value % 100)
    }

    mutating func append(_ digit: String) {
        if replacesOnInput {
            digits = ""
            replacesOnInput = false
        }
        guard digits.count < 4 else { return }
        // Leading zeros carry no value: "0", "5", "2" reads as 0h52.
        digits = String(Int(digits + digit) ?? 0)
    }

    mutating func deleteLast() {
        replacesOnInput = false
        if !digits.isEmpty { digits.removeLast() }
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
                .foregroundStyle(Color.tachoTextOnLight)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.white, in: RoundedRectangle(cornerRadius: 8.5, style: .continuous))
        }
    }
}
