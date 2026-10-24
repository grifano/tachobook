//
//  GaugeProgressView.swift
//  TachoBook
//

import SwiftUI

/// Figma "Half Circle Progress v2": a 270° arc with the limit, elapsed time and an optional warning.
public struct GaugeProgressView: View {
    public var limit: String
    public var value: String
    public var progress: Double // 0.0 to 1.0
    public var tint: Color
    public var warning: String?
    /// Beds on the Rest view, hammers on the Work view (owner decision 3, 23.10.2026).
    public var countIcon: ReducedRestRow.Icon
    /// Used (blue) icons in the always-visible row under the arc; nil while the count is unknown (all gray).
    public var reducedRestsUsed: Int?

    public init(limit: String, value: String, progress: Double, tint: Color, warning: String? = nil,
                countIcon: ReducedRestRow.Icon, reducedRestsUsed: Int?) {
        self.limit = limit
        self.value = value
        self.progress = progress
        self.tint = tint
        self.warning = warning
        self.countIcon = countIcon
        self.reducedRestsUsed = reducedRestsUsed
    }

    public var body: some View {
        // The row is its own accessibility element, outside the combined gauge label.
        ZStack(alignment: .bottom) {
            gauge
            ReducedRestRow(icon: countIcon, used: reducedRestsUsed)
        }
        .frame(width: 169, height: 161)
    }

    private var gauge: some View {
        ZStack(alignment: .top) {
            GaugeArc()
                .stroke(Color.tachoGaugeTrack, style: StrokeStyle(lineWidth: 21, lineCap: .round))
            if progress > 0 {
                GaugeArc(trimTo: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 21, lineCap: .round))
            }

            VStack(spacing: 0) {
                Text(limit)
                    .font(.footnote.weight(.semibold))
                    .frame(height: 22)
                FadedRule()
                    .frame(width: 60, height: 1)
                Text(value)
                    .font(.largeTitle)
                    // Thin "--:--" and "?" placeholders need a heavier stroke to stay legible.
                    .fontWeight(["--:--", "?"].contains(value) ? .black : nil)
                    .tracking(0.4)
                    .frame(height: 41)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.tachoTextOnLight)
            .frame(width: 96)
            .padding(.top, 51)

            // Below the value across the gauge's full width, so it is never clipped by the
            // 96 pt centre at large text sizes.
            if let warning {
                Label(warning, systemImage: "exclamationmark.circle")
                    .labelStyle(TightLabelStyle())
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.tachoTextOnLight)
                    .fixedSize()
                    .frame(width: 169)
                    .padding(.top, 115)
                    .accessibilityIdentifier("dutyWarning")
            }
        }
        .frame(width: 169, height: 161)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("homeGauge")
    }
}

/// Figma "Rest Count", always shown on the Home main widget: three icons, 8 pt apart, on the gauge's
/// bottom edge — 18 × 20 beds or 18 × 18 hammers (Figma 704:2659). Blue icons (left) are reductions used,
/// gray ones are still available; an unknown count shows all gray. Not interactive.
public struct ReducedRestRow: View {
    public enum Icon: Sendable {
        /// One reduced daily rest (9 h).
        case bed
        /// One extended duty period (up to 15 h): the same reduction seen from the Work view.
        case hammer

        var asset: String { self == .bed ? "RestCountIcon" : "WorkCountIcon" }
        var height: CGFloat { self == .bed ? 19.983 : 18 }
    }

    var icon: Icon
    var used: Int?

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<ReducedRestCounter.limit, id: \.self) { index in
                Image(icon.asset)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 18, height: icon.height)
                    .foregroundStyle(index < Self.usedIcons(used: used) ? Color.tachoBlue : TachoTheme.controlFill)
            }
        }
        // Hammers sit on the beds' baseline; the element keeps the bed row's 70 × 20 frame for VoiceOver.
        .frame(height: Icon.bed.height, alignment: .bottom)
        .contentShape(.accessibility, Rectangle())
        .offset(x: 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(icon: icon, used: used))
        .accessibilityIdentifier("reducedRestCount")
    }

    /// Blue (used) icons, never more than three; none while the count is unknown.
    static func usedIcons(used: Int?) -> Int {
        min(used ?? 0, ReducedRestCounter.limit)
    }

    /// The bed row's label (PR #11 wording).
    static func label(used: Int) -> String {
        label(icon: .bed, used: used)
    }

    static func label(icon: Icon, used: Int?) -> String {
        guard let used else { return icon == .bed ? "Reduced rests used: unknown" : "Extended shifts used: unknown" }
        let noun = icon == .bed ? "reduced rests" : "extended shifts"
        return used > ReducedRestCounter.limit
            ? "\(used) \(noun) used, limit \(ReducedRestCounter.limit)"
            : "\(used) of \(ReducedRestCounter.limit) \(noun) used"
    }
}

/// 270° arc whose gap faces down, sized like the Figma bar (radius 73 in a 169 × 161 frame).
struct GaugeArc: Shape {
    var trimTo: Double = 1.0

    var animatableData: Double {
        get { trimTo }
        set { trimTo = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width * (84.5 / 169), y: rect.height * (94.5 / 161))
        let radius = rect.width * (72.9 / 169)
        let sweep = 270 * max(0.001, min(1.0, trimTo))
        path.addArc(center: center, radius: radius, startAngle: .degrees(135),
                    endAngle: .degrees(135 + sweep), clockwise: false)
        return path
    }
}

/// Figma's hairline: gray at 40 % in the middle, fading out at both ends.
struct FadedRule: View {
    var axis: Axis = .horizontal

    var body: some View {
        let colors = [Color.tachoRule.opacity(0), Color.tachoRule.opacity(0.4), Color.tachoRule.opacity(0)]
        Rectangle()
            .fill(LinearGradient(colors: colors,
                                 startPoint: axis == .horizontal ? .leading : .top,
                                 endPoint: axis == .horizontal ? .trailing : .bottom))
            .accessibilityHidden(true)
    }
}

/// Icon and text separated by a single space, as in Figma's inline SF Symbols.
struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
