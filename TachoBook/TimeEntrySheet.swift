//
//  TimeEntrySheet.swift
//  TachoBook
//

import SwiftUI

/// Figma frames 02 and 05: date and time of a shift start or a rest start; Flow 4 · 09: the printout time.
/// Used to record new events and to edit existing ones (prefilled with the current value).
public struct TimeEntrySheet: View {
    public enum Kind {
        case shiftStart
        case restStart
        /// Flow 4 · 09: when the printout was made (decision 18). No symbol, as in Figma.
        case printout

        var title: String {
            switch self {
            case .shiftStart: "Shift start"
            case .restStart: "Rest start"
            case .printout: "Printout time"
            }
        }

        var subtitle: String {
            switch self {
            case .shiftStart: "When did your shift begin?"
            case .restStart: "When did your rest begin?"
            case .printout: "When did you print it?"
            }
        }

        var icon: String? {
            switch self {
            case .shiftStart: "SheetShiftStartIcon"
            case .restStart: "SheetRestStartIcon"
            case .printout: nil
            }
        }

        var iconHeight: CGFloat {
            switch self {
            case .shiftStart: 34.1
            case .restStart: 37.8
            case .printout: 0
            }
        }
    }

    var kind: Kind
    /// Limits the picker, e.g. to the day being edited; nil leaves it open.
    var range: ClosedRange<Date>?
    /// nil when the time can be confirmed, else why not (shown under the picker).
    var check: (Date) -> TimeEntryIssue?
    /// A red line when a valid time pushes the shift past its limit (decision 14); Confirm stays enabled.
    var warning: (Date) -> String?
    var onConfirm: (Date, ShiftPlace?) -> Void
    var onCancel: () -> Void
    /// The country row of «Flow - Country selection»; nil for sheets without a country.
    var country: CountryEntry?

    @State private var date: Date
    @State private var place: CountrySelection

    public init(kind: Kind, initialDate: Date, range: ClosedRange<Date>? = nil, check: @escaping (Date) -> TimeEntryIssue?,
                warning: @escaping (Date) -> String? = { _ in nil },
                onConfirm: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.init(kind: kind, initialDate: initialDate, range: range, check: check, warning: warning, country: nil,
                  onConfirm: { date, _ in onConfirm(date) }, onCancel: onCancel)
    }

    /// A sheet that also records where the driver is. `onConfirm` gets the chosen place (nil only for an
    /// edit of an older record left without a country).
    init(kind: Kind, initialDate: Date, range: ClosedRange<Date>? = nil, check: @escaping (Date) -> TimeEntryIssue?,
         warning: @escaping (Date) -> String? = { _ in nil }, country: CountryEntry?,
         onConfirm: @escaping (Date, ShiftPlace?) -> Void, onCancel: @escaping () -> Void) {
        self.kind = kind
        self.range = range
        self.check = check
        self.warning = warning
        self.country = country
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _date = State(initialValue: initialDate)
        _place = State(initialValue: country?.initial ?? CountrySelection(place: nil, source: .none))
    }

    private var canConfirm: Bool {
        check(date) == nil && (country.map { place.canConfirm(required: $0.required) } ?? true)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetToolbar(title: kind.title, subtitle: kind.subtitle, canConfirm: canConfirm,
                         onCancel: onCancel, onConfirm: { onConfirm(date, country == nil ? nil : place.place) })
            // Figma «Sheet Content» with the country row uses 12 pt gaps.
            VStack(spacing: country == nil ? 16 : 12) {
                if let icon = kind.icon {
                    SheetSymbol(image: icon, height: kind.iconHeight)
                }
                picker
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityIdentifier("sheetDatePicker")
                if let country {
                    CountryField(selection: $place, recents: country.recents)
                }
                // Why Confirm is disabled; sits below the picker so the picker never moves.
                // The F4 reason takes precedence: the red line shows only for a time that can be confirmed.
                let issue = check(date)
                let reason = issue?.message()
                let overLimit = issue == nil ? warning(date) : nil
                if let reason {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(Color.tachoTextOnLight)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("sheetReason")
                        .transition(.opacity)
                } else if let overLimit {
                    // The same style as the violation sheet's red line (Flow 3).
                    Text(overLimit)
                        .font(.body)
                        .foregroundStyle(TachoTheme.alertRedText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("sheetOverLimit")
                        .transition(.opacity)
                }
            }
            .padding(.top, 59)
            .animation(.default, value: check(date)?.message())
            .animation(.default, value: warning(date))
            Spacer(minLength: 24)
        }
        .foregroundStyle(Color.tachoTextOnLight)
        .environment(\.colorScheme, .light)
        .task {
            // Location runs after the sheet is up and never blocks Confirm (decision 2, 13.11.2026).
            guard let locator = country?.locator else { return }
            let detected = await locator.locate()
            withAnimation { place.apply(detected: detected) }
        }
        .presentationDetents([.height(country == nil ? 387 : 459)])
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

/// What a time sheet needs to show the country row.
struct CountryEntry {
    var initial: CountrySelection
    var recents: [TachoCountry]
    /// Looks the country up for a new Start or Close; nil for edits.
    var locator: CountryLocator?
    /// A new Start or Close cannot be saved without a country.
    var required: Bool
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
                        .foregroundStyle(Color.tachoTextOnLight)
                        .frame(width: 44, height: 44)
                        .background(TachoTheme.sheetCloseFill, in: Circle())
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("closeSheetButton")

                VStack(spacing: 0) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tachoTextOnLight)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.tachoTextOnLight)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

                Button(action: onConfirm) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.tachoTextOnDark)
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
