//
//  ViolationsView.swift
//  TachoBook
//

import SwiftUI

/// Figma "Flow 4 - Violations Tab" (750:15144): one list of every deviation in the records, newest first, not tied
/// to the header's date strip (decision 8); older than 56 days in a gray group (decisions 10, 15–17). A row opens
/// its sheet with the printout buttons. Updates every minute, so the days left change after midnight.
struct ViolationsView: View {
    var model: DayLogModel
    @State private var selected: ViolationKey?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            VStack(spacing: 0) {
                DashboardHeaderView(date: now, today: now, showsDateStrip: false)
                ScrollView {
                    ViolationsCard(rows: rows(now: now)) { selected = $0 }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background { HistoryBackground() }
        .sheet(item: $selected) { key in
            ViolationSheet(model: model, key: key, style: .list, onClose: { selected = nil })
        }
    }

    private func rows(now: Date) -> [ViolationsCard.Row] {
        model.violations(now: now).map { violation in
            let status = model.carryStatus(of: violation, now: now)
            return ViolationsCard.Row(key: violation.key, title: ViolationCopy.title(violation),
                                      subtitle: ViolationCopy.rowSubtitle(violation, status: status),
                                      isPrintoutDone: status.carryUntil != nil, isOlder: status.isOlder)
        }
    }
}

extension ViolationKey: Identifiable {
    public var id: String { storageID }
}

/// Figma "Violations List": the titled card with the rows, the gray group and the empty state.
struct ViolationsCard: View {
    struct Row: Identifiable, Equatable {
        var key: ViolationKey
        var title: String
        var subtitle: String
        var isPrintoutDone: Bool
        var isOlder: Bool
        var id: ViolationKey { key }
    }

    var rows: [Row]
    var onSelect: (ViolationKey) -> Void

    var body: some View {
        let recent = rows.filter { !$0.isOlder }
        let older = rows.filter(\.isOlder)
        VStack(alignment: .leading, spacing: 16) {
            Label("Violations", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(SpacedLabelStyle())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TachoTheme.headerBlueText)
                .accessibilityAddTraits(.isHeader)
            if rows.isEmpty {
                VStack(spacing: 4) {
                    Text("No violations").font(.body)
                    // Medium weight, as the row subtitles: Caption 1 regular fails the contrast audit on the glass card.
                    Text("Your records show no limit passed.").font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.tachoTextOnLight)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("violationsEmpty")
            }
            ForEach(recent) { row in rowButton(row) }
            if !older.isEmpty {
                Text("Older than 56 days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.tachoTextOnLight)
                    .opacity(Self.olderTextOpacity)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("olderGroupLabel")
                ForEach(older) { row in rowButton(row) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeWidgetBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("violationsList")
    }

    /// Figma dims older rows to 50 %. Their status icon and chevron are dimmed so; their text only to 85 %, which
    /// keeps it above the audit's contrast minimum on the glass card.
    static let olderOpacity = 0.5
    static let olderTextOpacity = 0.85

    private func rowButton(_ row: Row) -> some View {
        Button { onSelect(row.key) } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.body)
                    // Medium weight, as the Home widget subtitles: Caption 1 regular fails the contrast audit on glass.
                    Text(row.subtitle).font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.tachoTextOnLight)
                .opacity(row.isOlder ? Self.olderTextOpacity : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: row.isPrintoutDone ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(row.isPrintoutDone ? TachoTheme.successGreenText : TachoTheme.alertRedText)
                    .opacity(row.isOlder ? Self.olderOpacity : 1)
                HStack(spacing: 16) {
                    Text("Detail").font(.body)
                        .opacity(row.isOlder ? Self.olderTextOpacity : 1)
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .imageScale(.small)
                        .opacity(row.isOlder ? Self.olderOpacity : 1)
                }
                .foregroundStyle(Color.tachoTextOnLight)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title), \(row.subtitle.replacingOccurrences(of: " · ?", with: ""))")
        .accessibilityValue(row.isPrintoutDone ? "Printout done" : "Printout missing")
        .accessibilityHint("Shows details")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("violationRow")
    }
}
