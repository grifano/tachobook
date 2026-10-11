//
//  TachoSymbols.swift
//  TachoBook
//

import SwiftUI

/// EU Tachograph Symbol for Start of Shift: Bar followed by right-pointing triangle (|►)
public struct ShiftStartSymbol: View {
    public var color: Color = .tachoDark

    public init(color: Color = .tachoDark) {
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // Left vertical bar
                let barWidth = w * (4.588 / 26.0)
                let barRect = CGRect(x: 0, y: 0, width: barWidth, height: h)
                path.addRoundedRect(in: barRect, cornerSize: CGSize(width: barWidth * 0.2, height: barWidth * 0.2))

                // Right arrow
                let startX = w * (7.64 / 26.0)
                let arrowPeakX = w * (25.36 / 26.0)
                path.move(to: CGPoint(x: startX, y: 0))
                path.addLine(to: CGPoint(x: w * (11.2 / 26.0), y: 0))
                path.addLine(to: CGPoint(x: arrowPeakX, y: h * 0.5))
                path.addLine(to: CGPoint(x: w * (11.2 / 26.0), y: h))
                path.addLine(to: CGPoint(x: startX, y: h))
                path.closeSubpath()
            }
            .fill(color)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// EU Tachograph Symbol for End of Shift: Right-pointing triangle into bar (►|)
public struct ShiftEndSymbol: View {
    public var color: Color = .tachoDark

    public init(color: Color = .tachoDark) {
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // Left arrow
                let arrowPeakX = w * (17.5 / 26.0)
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: w * (3.5 / 26.0), y: 0))
                path.addLine(to: CGPoint(x: arrowPeakX, y: h * 0.5))
                path.addLine(to: CGPoint(x: w * (3.5 / 26.0), y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()

                // Right vertical bar
                let barWidth = w * (4.588 / 26.0)
                let barX = w - barWidth
                let barRect = CGRect(x: barX, y: 0, width: barWidth, height: h)
                path.addRoundedRect(in: barRect, cornerSize: CGSize(width: barWidth * 0.2, height: barWidth * 0.2))
            }
            .fill(color)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// EU Tachograph Symbol for Driving (Steering wheel)
public struct TachoDrivingSymbol: View {
    public var color: Color = .tachoDark

    public init(color: Color = .tachoDark) {
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sx = w / 18.0
            let sy = h / 18.0

            Path { path in
                // Left curve
                path.addPath(Path { p in
                    p.move(to: CGPoint(x: 3.6 * sx, y: 3.6 * sy))
                    p.addLine(to: CGPoint(x: 3.6 * sx, y: 14.4 * sy))
                    p.addLine(to: CGPoint(x: 1.677 * sx, y: 14.4 * sy))
                    p.addQuadCurve(to: CGPoint(x: 0, y: 12.723 * sy), control: CGPoint(x: 0, y: 14.4 * sy))
                    p.addLine(to: CGPoint(x: 0, y: 5.277 * sy))
                    p.addQuadCurve(to: CGPoint(x: 1.677 * sx, y: 3.6 * sy), control: CGPoint(x: 0, y: 3.6 * sy))
                    p.closeSubpath()
                })
                // Right curve
                path.addPath(Path { p in
                    p.move(to: CGPoint(x: 16.323 * sx, y: 3.6 * sy))
                    p.addQuadCurve(to: CGPoint(x: 18 * sx, y: 5.277 * sy), control: CGPoint(x: 18 * sx, y: 3.6 * sy))
                    p.addLine(to: CGPoint(x: 18 * sx, y: 12.723 * sy))
                    p.addQuadCurve(to: CGPoint(x: 16.323 * sx, y: 14.4 * sy), control: CGPoint(x: 18 * sx, y: 14.4 * sy))
                    p.addLine(to: CGPoint(x: 14.4 * sx, y: 14.4 * sy))
                    p.addLine(to: CGPoint(x: 14.4 * sx, y: 3.6 * sy))
                    p.closeSubpath()
                })
                // Bottom curve
                path.addPath(Path { p in
                    p.move(to: CGPoint(x: 14.4 * sx, y: 16.323 * sy))
                    p.addQuadCurve(to: CGPoint(x: 12.723 * sx, y: 18 * sy), control: CGPoint(x: 14.4 * sx, y: 18 * sy))
                    p.addLine(to: CGPoint(x: 5.277 * sx, y: 18 * sy))
                    p.addQuadCurve(to: CGPoint(x: 3.6 * sx, y: 16.323 * sy), control: CGPoint(x: 3.6 * sx, y: 18 * sy))
                    p.addLine(to: CGPoint(x: 3.6 * sx, y: 14.4 * sy))
                    p.addLine(to: CGPoint(x: 14.4 * sx, y: 14.4 * sy))
                    p.closeSubpath()
                })
                // Top curve
                path.addPath(Path { p in
                    p.move(to: CGPoint(x: 14.4 * sx, y: 3.6 * sy))
                    p.addLine(to: CGPoint(x: 3.6 * sx, y: 3.6 * sy))
                    p.addLine(to: CGPoint(x: 3.6 * sx, y: 1.677 * sy))
                    p.addQuadCurve(to: CGPoint(x: 5.277 * sx, y: 0), control: CGPoint(x: 3.6 * sx, y: 0))
                    p.addLine(to: CGPoint(x: 12.723 * sx, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 14.4 * sx, y: 1.677 * sy), control: CGPoint(x: 14.4 * sx, y: 0))
                    p.closeSubpath()
                })
                // Center hub
                path.addRoundedRect(in: CGRect(x: 7.2 * sx, y: 7.2 * sy, width: 3.6 * sx, height: 3.6 * sy), cornerSize: CGSize(width: 1.8 * sx, height: 1.8 * sy))
            }
            .fill(color)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// EU Tachograph Symbol for Rest (Bed)
public struct TachoRestSymbol: View {
    public var color: Color = .tachoDark

    public init(color: Color = .tachoDark) {
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sx = w / 18.0
            let sy = h / 18.0

            Path { p in
                p.move(to: CGPoint(x: 0, y: 1 * sy))
                p.addQuadCurve(to: CGPoint(x: 1 * sx, y: 0), control: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 2.6 * sx, y: 0))
                p.addQuadCurve(to: CGPoint(x: 3.6 * sx, y: 1 * sy), control: CGPoint(x: 3.6 * sx, y: 0))
                p.addLine(to: CGPoint(x: 3.6 * sx, y: 6.2 * sy))
                p.addQuadCurve(to: CGPoint(x: 4.6 * sx, y: 7.2 * sy), control: CGPoint(x: 3.6 * sx, y: 7.2 * sy))
                p.addLine(to: CGPoint(x: 17 * sx, y: 7.2 * sy))
                p.addQuadCurve(to: CGPoint(x: 18 * sx, y: 8.2 * sy), control: CGPoint(x: 18 * sx, y: 7.2 * sy))
                p.addLine(to: CGPoint(x: 18 * sx, y: 17 * sy))
                p.addQuadCurve(to: CGPoint(x: 17 * sx, y: 18 * sy), control: CGPoint(x: 18 * sx, y: 18 * sy))
                p.addLine(to: CGPoint(x: 15.4 * sx, y: 18 * sy))
                p.addQuadCurve(to: CGPoint(x: 14.4 * sx, y: 17 * sy), control: CGPoint(x: 14.4 * sx, y: 18 * sy))
                p.addLine(to: CGPoint(x: 14.4 * sx, y: 11.8 * sy))
                p.addQuadCurve(to: CGPoint(x: 13.4 * sx, y: 10.8 * sy), control: CGPoint(x: 14.4 * sx, y: 10.8 * sy))
                p.addLine(to: CGPoint(x: 4.6 * sx, y: 10.8 * sy))
                p.addQuadCurve(to: CGPoint(x: 3.6 * sx, y: 11.8 * sy), control: CGPoint(x: 3.6 * sx, y: 10.8 * sy))
                p.addLine(to: CGPoint(x: 3.6 * sx, y: 17 * sy))
                p.addQuadCurve(to: CGPoint(x: 2.6 * sx, y: 18 * sy), control: CGPoint(x: 3.6 * sx, y: 18 * sy))
                p.addLine(to: CGPoint(x: 1 * sx, y: 18 * sy))
                p.addQuadCurve(to: CGPoint(x: 0, y: 17 * sy), control: CGPoint(x: 0, y: 18 * sy))
                p.closeSubpath()
            }
            .fill(color)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
