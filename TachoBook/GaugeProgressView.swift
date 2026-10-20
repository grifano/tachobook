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
    /// Figma "Rest Count" under the arc; nil hides the row (count unknown, or not a rest gauge).
    public var reducedRestsUsed: Int?

    public init(limit: String, value: String, progress: Double, tint: Color, warning: String? = nil,
                reducedRestsUsed: Int? = nil) {
        self.limit = limit
        self.value = value
        self.progress = progress
        self.tint = tint
        self.warning = warning
        self.reducedRestsUsed = reducedRestsUsed
    }

    public var body: some View {
        // The bed row is its own accessibility element, outside the combined gauge label.
        ZStack(alignment: .bottom) {
            gauge
            if let reducedRestsUsed {
                ReducedRestRow(used: reducedRestsUsed)
            }
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

/// Figma "Rest Count": three 18 × 20 beds, 8 pt apart, on the gauge's bottom edge.
/// Red beds (left) are reductions used, blue beds are still available. Not interactive.
struct ReducedRestRow: View {
    var used: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<ReducedRestCounter.limit, id: \.self) { index in
                Image("RestCountIcon")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 18, height: 19.983)
                    .foregroundStyle(index < used ? Color.tachoRed : Color.tachoBlue)
            }
        }
        .offset(x: 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(used: used))
        .accessibilityIdentifier("reducedRestCount")
    }

    static func label(used: Int) -> String {
        used > ReducedRestCounter.limit
            ? "\(used) reduced rests used, limit \(ReducedRestCounter.limit)"
            : "\(used) of \(ReducedRestCounter.limit) reduced rests used"
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
