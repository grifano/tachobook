//
//  GaugeProgressView.swift
//  TachoBook
//

import SwiftUI

public struct GaugeProgressView: View {
    public var title: String
    public var value: String
    public var progress: Double // 0.0 to 1.0
    public var progressColor: Color

    public init(
        title: String,
        value: String,
        progress: Double,
        progressColor: Color = .tachoOrange
    ) {
        self.title = title
        self.value = value
        self.progress = progress
        self.progressColor = progressColor
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
                Text(value)
                    .font(.system(.title, weight: .bold))
                    .foregroundColor(.tachoDark)
                    .offset(y: 4)
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
