//
//  GaugeProgressView.swift
//  TachoBook
//

import SwiftUI

public struct GaugeProgressView: View {
    @ScaledMetric(relativeTo: .caption2) private var secondsFontSize = 8
    public var title: String
    public var value: String
    public var progress: Double // 0.0 to 1.0
    public var secondaryValue: String?
    public var progressColor: Color

    public init(
        title: String,
        value: String,
        progress: Double,
        progressColor: Color = .tachoOrange,
        secondaryValue: String? = nil
    ) {
        self.title = title
        self.value = value
        self.progress = progress
        self.progressColor = progressColor
        self.secondaryValue = secondaryValue
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Track
                GaugeArc()
                    .stroke(
                        Color.tachoTrackGray,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )

                // Foreground Progress
                if progress > 0 {
                    GaugeArc(trimTo: progress)
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                }

                // Center Value Text
                VStack(spacing: 0) {
                    Text(value)
                        .accessibilityIdentifier(title == "Shift elapsed" ? "shiftHoursMinutes" : "gaugeValue")
                        .font(.system(.title, weight: .bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let secondaryValue {
                        Text(secondaryValue).font(.system(size: secondsFontSize, weight: .bold))
                            .tracking(0.38)
                            .accessibilityIdentifier("shiftSeconds")
                    }
                }
                .monospacedDigit()
                .foregroundStyle(Color.tachoDark)
                .offset(y: secondaryValue == nil ? 4 : 7)
            }
            .aspectRatio(136 / 114, contentMode: .fit)
            .frame(maxWidth: 136)

            // Subtitle
            Text(title)
                .font(.caption)
                .foregroundColor(.tachoDark)
        }
    }
}

/// Shape representing the 270-degree speedometer-style arc
struct GaugeArc: Shape {
    var trimTo: Double = 1.0

    var animatableData: Double {
        get { trimTo }
        set { trimTo = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.width * (9.0 / 136.0))
        let radius = rect.width / 2 - rect.width * (8.0 / 136.0)

        let startAngle = Angle.degrees(135)
        let totalSweep: Double = 270
        let endAngle = Angle.degrees(135 + totalSweep * max(0.001, min(1.0, trimTo)))

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
