//
//  TimeEntrySheet.swift
//  TachoBook
//

import SwiftUI

/// Figma frames 02 and 05: date and time of a shift start or a rest start.
/// Used to record new events and to edit existing ones (prefilled with the current value).
public struct TimeEntrySheet: View {
    public enum Kind {
        case shiftStart
        case restStart

        var title: String {
            switch self {
            case .shiftStart: "Shift start"
            case .restStart: "Rest start"
            }
        }

        var subtitle: String {
            switch self {
            case .shiftStart: "When did your shift begin?"
            case .restStart: "When did your rest begin?"
            }
        }

        var icon: String {
            switch self {
            case .shiftStart: "SheetShiftStartIcon"
            case .restStart: "SheetRestStartIcon"
            }
        }

        var iconHeight: CGFloat {
            switch self {
            case .shiftStart: 34.1
            case .restStart: 37.8
            }
        }
    }

    var kind: Kind
    /// Limits the picker, e.g. to the day being edited; nil leaves it open.
    var range: ClosedRange<Date>?
    var isValid: (Date) -> Bool
    var onConfirm: (Date) -> Void
    var onCancel: () -> Void

    @State private var date: Date

    public init(kind: Kind, initialDate: Date, range: ClosedRange<Date>? = nil, isValid: @escaping (Date) -> Bool,
                onConfirm: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.kind = kind
        self.range = range
        self.isValid = isValid
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _date = State(initialValue: initialDate)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetToolbar(title: kind.title, subtitle: kind.subtitle, canConfirm: isValid(date),
                         onCancel: onCancel, onConfirm: { onConfirm(date) })
            VStack(spacing: 16) {
                SheetSymbol(image: kind.icon, height: kind.iconHeight)
                picker
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityIdentifier("sheetDatePicker")
            }
            .padding(.top, 59)
            Spacer(minLength: 24)
        }
        .foregroundStyle(Color.tachoDark)
        .environment(\.colorScheme, .light)
        .presentationDetents([.height(387)])
        .presentationDragIndicator(.hidden)
        .presentationBackground {
            Rectangle().fill(Color(red: 245/255, green: 245/255, blue: 245/255).opacity(0.94))
        }
    }
}

extension TimeEntrySheet {
    @ViewBuilder fileprivate var picker: some View {
        if let range {
            DatePicker(kind.title, selection: $date, in: range, displayedComponents: [.date, .hourAndMinute])
        } else {
            DatePicker(kind.title, selection: $date, displayedComponents: [.date, .hourAndMinute])
        }
    }
}

/// Figma "Toolbar - Top - Sheet": orange grabber, close and confirm buttons, centred titles.
struct SheetToolbar: View {
    var title: String
    var subtitle: String
    var canConfirm: Bool
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.tachoOrange)
                .frame(width: 36, height: 5)
                .padding(.top, 5)
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.tachoDark)
                        .frame(width: 44, height: 44)
                        .background(TachoTheme.sheetCloseFill, in: Circle())
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("closeSheetButton")

                VStack(spacing: 0) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tachoDark)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TachoTheme.sheetSubtitle)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

                Button(action: onConfirm) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(canConfirm ? Color.tachoOrange : TachoTheme.controlFill, in: Circle())
                }
                .disabled(!canConfirm)
                .accessibilityLabel("Confirm")
                .accessibilityIdentifier("confirmSheetButton")
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

/// Figma "Tacho Symbol Image": a 68 pt circle holding the event icon.
struct SheetSymbol: View {
    var image: String
    var height: CGFloat

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: height)
            .frame(width: 68, height: 68)
            .background(TachoTheme.iconCircleFill, in: Circle())
            .accessibilityHidden(true)
    }
}
