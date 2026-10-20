import SwiftUI
import Testing
import UIKit
@testable import TachoBook

/// F9: text uses two named colours, the same in Light and Dark mode.
struct TextColourTests {
    private func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> [Int] {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { Int(($0 * 255).rounded()) }
    }

    @Test func textOnLightIsLabelsPrimaryInBothModes() {
        #expect(rgb(.tachoTextOnLight, .light) == [0x07, 0x2B, 0x3C, 255])
        #expect(rgb(.tachoTextOnLight, .dark) == [0x07, 0x2B, 0x3C, 255])
    }

    @Test func textOnDarkIsWhiteInBothModes() {
        #expect(rgb(.tachoTextOnDark, .light) == [255, 255, 255, 255])
        #expect(rgb(.tachoTextOnDark, .dark) == [255, 255, 255, 255])
    }

    /// Navy on the light card surface (a #F5F5F5 fill at 80 %, at worst over a white backdrop) reaches AA.
    @Test func navyOnTheLightSurfaceReachesAA() {
        func luminance(_ c: [Double]) -> Double {
            let lin = c.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
        }
        let navy = luminance([7, 43, 60].map { $0 / 255 })
        let surface = luminance([245, 245, 245].map { $0 / 255 })
        #expect((surface + 0.05) / (navy + 0.05) >= 4.5)
    }
}
