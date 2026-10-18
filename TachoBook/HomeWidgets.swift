//
//  HomeWidgets.swift
//  TachoBook
//

import SwiftUI

/// The Work/Rest toggle only changes what Home shows, never the shift state.
public enum HomeTab: String, Hashable {
    case work
    case rest
}

struct HomeTabPicker: View {
    @Binding var selection: HomeTab
    var isRestEnabled: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment(.work, title: "Work")
            segment(.rest, title: "Rest")
        }
        .padding(3)
        .background(TachoTheme.controlFill, in: Capsule())
    }

    private func segment(_ tab: HomeTab, title: String) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(labelColor(for: tab))
                .lineLimit(1)
                .frame(minWidth: 64, minHeight: 28)
                .background {
                    if isSelected { Capsule().fill(.white) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(tab == .rest && !isRestEnabled)
        .accessibilityIdentifier("\(tab.rawValue)Segment")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func labelColor(for tab: HomeTab) -> Color {
        switch selection {
        case .rest: .tachoBlue
        case .work: tab == .work ? .tachoOrange : .tachoDark
        }
    }
}

struct HomeLimit: Identifiable {
    var label: String
    var value: String
    var id: String { label }
}

/// Figma "Main widget": icon, title, Work/Rest toggle, gauge and two clock-time limits.
struct HomeMainWidget: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var icon: String
    var iconSize: CGSize
    var title: String
    var subtitle: String
    var accent: Color
    @Binding var tab: HomeTab
    var isRestEnabled: Bool
    var gauge: GaugeProgressView
    var limits: [HomeLimit]

    var body: some View {
        // Rows as in Figma; at accessibility sizes they stack. AnyLayout keeps the same
        // views while switching, so text keeps scaling instead of being replaced.
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let header = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 8))
        let content = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 0))
        VStack(alignment: .leading, spacing: 16) {
            header {
                titleBlock
                if !isLarge { Spacer(minLength: 0) }
                HomeTabPicker(selection: $tab, isRestEnabled: isRestEnabled)
            }
            content {
                gauge
                    .padding(.trailing, isLarge ? 0 : 16)
                    .frame(maxWidth: isLarge ? .infinity : nil)
                limitsColumn
                    .padding(.leading, isLarge ? 0 : 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        if !isLarge { FadedRule(axis: .vertical).frame(width: 1, height: 137) }
                    }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeWidgetBackground()
    }

    private var titleBlock: some View {
        HStack(spacing: 19) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize.width, height: iconSize.height)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.caption)
            }
            .foregroundStyle(accent)
            .homeTextFit()
        }
    }

    private var limitsColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(limits.enumerated()), id: \.element.id) { index, limit in
                if index > 0 { FadedRule().frame(height: 1) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(limit.label)
                        .font(.subheadline.weight(.semibold))
                    Label(limit.value, systemImage: "clock")
                        .labelStyle(TightLabelStyle())
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                .foregroundStyle(Color.tachoDark)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("limit\(index)")
            }
        }
    }
}

enum HomeButtonStyle {
    case primary
    case done
    case dimmed

    var fill: Color {
        switch self {
        case .primary: .tachoOrange
        case .done: TachoTheme.doneFill
        case .dimmed: TachoTheme.controlFill
        }
    }

    var label: Color {
        switch self {
        case .primary: .white
        case .done: TachoTheme.doneLabel
        case .dimmed: TachoTheme.dimmedLabel
        }
    }
}

/// Figma "Button - Content Area": a capsule with a large symbol and one or two lines.
struct HomeCapsuleLabel: View {
    var symbol: String
    var title: String
    var subtitle: String?
    var style: HomeButtonStyle
    var titleFont: Font = .subheadline.weight(.semibold)
    var subtitleFont: Font = .body

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title.bold())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(titleFont)
                if let subtitle {
                    Text(subtitle).font(subtitleFont).monospacedDigit()
                }
            }
            .homeTextFit()
        }
        .foregroundStyle(style.label)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(style.fill, in: Capsule())
        .contentShape(Capsule())
        .accessibilityIdentifier("capsule \(title)")
    }
}

struct HomeSummaryItem: Identifiable {
    var symbol: String
    var label: String
    var value: String
    var identifier: String
    var action: () -> Void
    var id: String { identifier }
}

/// Figma "Secondary Widget": a titled card with two or three centred values.
struct HomeSecondaryCard<Item: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var symbol: String
    var title: String
    var count: Int
    @ViewBuilder var item: (Int) -> Item

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .labelStyle(SpacedLabelStyle())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.tachoBlue)
                .accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 20))
            layout { columns(rules: !dynamicTypeSize.isAccessibilitySize) }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeWidgetBackground()
    }

    @ViewBuilder private func columns(rules: Bool) -> some View {
        ForEach(0..<count, id: \.self) { index in
            if index > 0 && rules {
                FadedRule(axis: .vertical).frame(width: 1, height: 44)
            }
            item(index)
        }
    }
}

/// A caption over a value, used by both secondary cards.
struct HomeValueColumn: View {
    var symbol: String?
    var label: String
    var value: String
    var valueSymbol: String?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol).fontWeight(.bold).accessibilityHidden(true)
                }
                Text(label)
            }
            .font(.footnote)
            HStack(spacing: 4) {
                if let valueSymbol {
                    Image(systemName: valueSymbol).accessibilityHidden(true)
                }
                Text(value).monospacedDigit()
            }
            .font(.headline)
        }
        .foregroundStyle(Color.tachoDark)
        .multilineTextAlignment(.center)
        .homeTextFit()
    }
}

struct SpacedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
            configuration.title
        }
    }
}

/// One line as in Figma at standard text sizes, shrinking slightly on narrow screens;
/// at larger sizes text wraps instead so it is never clipped.
private struct HomeTextFit: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize <= .large {
            content.lineLimit(1).minimumScaleFactor(0.8)
        } else {
            content.fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    func homeTextFit() -> some View { modifier(HomeTextFit()) }
}
