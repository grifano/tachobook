//
//  HistoryView.swift
//  TachoBook
//

import SwiftUI
import UIKit

/// Figma "Flow 3 - View History", frame 01 (708:31832): the month calendar with day markers and a legend.
/// A tap on a date opens the read-only Day summary sheet (frame 02, 708:31844). Browsing never writes.
struct HistoryView: View {
    var model: DayLogModel
    @State private var summaryDay: SummaryDay?

    struct SummaryDay: Identifiable {
        var date: Date
        var id: Date { date }
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            VStack(spacing: 0) {
                // Header as on Home; a reachable date in the strip opens its summary like a calendar tap.
                DashboardHeaderView(date: now, today: now,
                                    onSelect: { summaryDay = SummaryDay(date: DayHistory.day(daysBack: $0, from: now)) })
                ScrollView {
                    calendarCard(now: now)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background { HistoryBackground() }
        .sheet(item: $summaryDay) { day in
            DaySummarySheet(model: model, day: day.date, onClose: { summaryDay = nil })
        }
    }

    private func calendarCard(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HistoryCalendar(markers: model.historyMarkers(now: now), today: now) { date in
                summaryDay = SummaryDay(date: date)
            }
            .accessibilityIdentifier("historyCalendar")
            FadedRule().frame(height: 1).padding(.horizontal, 16)
            HistoryLegend()
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: TachoTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TachoTheme.cardRadius, style: .continuous)
                .strokeBorder(Color.tachoCardBorder, lineWidth: 1)
        }
        .environment(\.colorScheme, .light)
    }
}

/// The Home photo with its darker top, behind the header and the card.
private struct HistoryBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Image("DashboardBackground")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.2))
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 480)
        }
        .ignoresSafeArea()
    }
}

/// Figma "Legenda" with the interim copy of owner decision 6: the hint, then bed and wheel.
/// The "Rule broken this day" line comes with the violations task (decision 3).
struct HistoryLegend: View {
    /// One column for both icons (the bed is wider than the wheel), so the texts line up.
    @ScaledMetric(relativeTo: .caption2) private var iconWidth: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap a date to see that day.")
                .font(.callout.italic())
            ForEach(Entry.all, id: \.symbol) { entry in
                HStack(spacing: 8) {
                    // About 10 pt at the default size, scaling with the text.
                    Image(systemName: entry.symbol)
                        .font(.caption2.weight(.semibold))
                        .imageScale(.small)
                        .foregroundStyle(Color.tachoBlue)
                        .frame(width: iconWidth)
                        .accessibilityHidden(true)
                    Text(entry.text).font(.caption2)
                }
            }
        }
        .foregroundStyle(Color.tachoTextOnLight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("historyLegend")
    }

    struct Entry {
        var symbol: String
        var text: String
        static let all = [
            Entry(symbol: HistoryMarkerSymbol.reducedRest, text: "Reduced rest (9–11 h)"),
            Entry(symbol: HistoryMarkerSymbol.extendedDriving, text: "Extended driving (10 h)"),
        ]
    }
}

/// SF Symbols of the Figma markers "Icon / Rest" and "Icon / Drive", in the brand blue (#116B93).
enum HistoryMarkerSymbol {
    static let reducedRest = "bed.double.fill"
    static let extendedDriving = "steeringwheel"
}

// MARK: - Native calendar (owner decision 1)

/// `UICalendarView` with decorations for the markers and single-date selection for taps. Future dates are
/// outside the available range, so they are dimmed and cannot be selected.
struct HistoryCalendar: UIViewRepresentable {
    var markers: [Date: HistoryDayMarkers]
    var today: Date
    var onSelect: (Date) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = .current
        view.locale = .current
        view.fontDesign = .default
        // Navy, not the Figma orange: F9 allows only navy text on light surfaces. Today stays highlighted by the
        // system (bold, tinted) and the selection circle is navy with white text.
        view.tintColor = UIColor(Color.tachoTextOnLight)
        view.backgroundColor = .clear
        view.overrideUserInterfaceStyle = .light
        view.wantsDateDecorations = true
        view.delegate = context.coordinator
        context.coordinator.calendarView = view
        view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.availableDateRange = Self.availableRange(today: today)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        let coordinator = context.coordinator
        let changed = Set(coordinator.parent.markers.keys).union(markers.keys)
            .filter { coordinator.parent.markers[$0] != markers[$0] }
        coordinator.parent = self
        let range = Self.availableRange(today: today)
        if view.availableDateRange != range { view.availableDateRange = range }
        guard !changed.isEmpty else { return }
        let components = changed.map { view.calendar.dateComponents([.year, .month, .day], from: $0) }
        view.reloadDecorations(forDateComponents: components, animated: true)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? 370
        let size = uiView.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                  withHorizontalFittingPriority: .required,
                                                  verticalFittingPriority: .fittingSizeLevel)
        return CGSize(width: width, height: size.height)
    }

    /// From the distant past up to the last second of today.
    static func availableRange(today: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: today)
        let end = calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? today
        return DateInterval(start: .distantPast, end: end)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: HistoryCalendar
        weak var calendarView: UICalendarView?

        init(_ parent: HistoryCalendar) { self.parent = parent }

        func calendarView(_ calendarView: UICalendarView,
                          decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = calendarView.calendar.date(from: dateComponents),
                  let markers = parent.markers[calendarView.calendar.startOfDay(for: date)], !markers.isEmpty
            else { return nil }
            guard let image = HistoryMarkerRow.image(markers) else { return nil }
            return .customView {
                let view = UIImageView(image: image)
                view.isAccessibilityElement = true
                view.accessibilityLabel = markers.spokenNames.joined(separator: ", ")
                return view
            }
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let date = calendarView?.calendar.date(from: dateComponents) else { return }
            // No lasting selection: the same date can be tapped again after the sheet closes.
            selection.setSelected(nil, animated: true)
            parent.onSelect(date)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            guard let dateComponents, let date = calendarView?.calendar.date(from: dateComponents) else { return false }
            return date <= parent.today
        }
    }
}

/// The 10 pt icons under a date, side by side as in Figma's "Row" (wheel, then bed), drawn into one image.
enum HistoryMarkerRow {
    static func image(_ markers: HistoryDayMarkers) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        var symbols: [String] = []
        if markers.contains(.extendedDriving) { symbols.append(HistoryMarkerSymbol.extendedDriving) }
        if markers.contains(.reducedRest) { symbols.append(HistoryMarkerSymbol.reducedRest) }
        let images = symbols.compactMap {
            UIImage(systemName: $0, withConfiguration: configuration)?
                .withTintColor(UIColor(Color.tachoBlue), renderingMode: .alwaysOriginal)
        }
        guard !images.isEmpty else { return nil }
        let spacing: CGFloat = 4
        let height = images.map(\.size.height).max() ?? 10
        let width = images.map(\.size.width).reduce(0, +) + spacing * CGFloat(images.count - 1)
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { _ in
            var x: CGFloat = 0
            for image in images {
                image.draw(at: CGPoint(x: x, y: (height - image.size.height) / 2))
                x += image.size.width + spacing
            }
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
}
