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

    public init(limit: String, value: String, progress: Double, tint: Color, warning: String? = nil) {
        self.limit = limit
        self.value = value
        self.progress = progress
        self.tint = tint
        self.warning = warning
    }

    public var body: some View {
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
                    .tracking(0.4)
                    .frame(height: 41)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.tachoDark)
            .frame(width: 96)
            .padding(.top, 51)

            // Below the value across the gauge's full width, so it is never clipped by the
            // 96 pt centre at large text sizes.
            if let warning {
                Label(warning, systemImage: "exclamationmark.circle")
                    .labelStyle(TightLabelStyle())
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(TachoTheme.warningText)
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
