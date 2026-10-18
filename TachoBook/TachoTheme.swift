//
//  TachoTheme.swift
//  TachoBook
//

import SwiftUI

public enum TachoTheme {
    public static let primaryOrange = Color(red: 232/255, green: 101/255, blue: 42/255) // #E8652A
    public static let primaryDark = Color(red: 7/255, green: 43/255, blue: 60/255)     // #072B3C
    public static let secondaryText = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.6)
    public static let cardBorder = Color(red: 17/255, green: 107/255, blue: 147/255).opacity(0.5)
    public static let successGreen = Color(red: 74/255, green: 153/255, blue: 101/255) // #4A9965
    public static let alertRed = Color(red: 222/255, green: 99/255, blue: 90/255)      // #DE635A
    public static let statusBlue = Color(red: 17/255, green: 107/255, blue: 147/255)   // #116B93
    public static let grayFill = Color(red: 228/255, green: 228/255, blue: 228/255)    // #E4E4E4
    public static let trackGray = Color(red: 229/255, green: 229/255, blue: 234/255)   // #E5E5EA
    public static let separator = Color(red: 230/255, green: 230/255, blue: 230/255)   // #E6E6E6
    public static let cardRadius: CGFloat = 20
    public static let buttonRadius: CGFloat = 1000

    // Home (Figma "Flow 1 - Log Day Shift")
    public static let widgetRadius: CGFloat = 34
    public static let widgetFill = Color(red: 245/255, green: 245/255, blue: 245/255).opacity(0.8)
    public static let gaugeTrack = Color(red: 209/255, green: 209/255, blue: 214/255)       // #D1D1D6
    public static let rule = Color(red: 120/255, green: 120/255, blue: 120/255)             // #787878
    public static let controlFill = Color(red: 120/255, green: 120/255, blue: 120/255).opacity(0.4)
    public static let dimmedLabel = Color(red: 191/255, green: 191/255, blue: 191/255)      // #BFBFBF
    public static let doneFill = Color(red: 163/255, green: 208/255, blue: 179/255)         // #A3D0B3
    public static let doneLabel = Color(red: 45/255, green: 92/255, blue: 64/255)           // #2D5C40
    public static let sheetSubtitle = Color(red: 114/255, green: 114/255, blue: 114/255)    // #727272
    public static let sheetCloseFill = Color(red: 116/255, green: 116/255, blue: 128/255).opacity(0.08)
    public static let iconCircleFill = Color(red: 228/255, green: 228/255, blue: 228/255).opacity(0.3)
}

extension Color {
    public static var tachoOrange: Color { TachoTheme.primaryOrange }
    public static var tachoDark: Color { TachoTheme.primaryDark }
    public static var tachoSecondary: Color { TachoTheme.secondaryText }
    public static var tachoGreen: Color { TachoTheme.successGreen }
    public static var tachoRed: Color { TachoTheme.alertRed }
    public static var tachoBlue: Color { TachoTheme.statusBlue }
    public static var tachoGray: Color { TachoTheme.grayFill }
    public static var tachoTrackGray: Color { TachoTheme.trackGray }
    public static var tachoSeparator: Color { TachoTheme.separator }
    public static var tachoCardBorder: Color { TachoTheme.cardBorder }
    public static var tachoGaugeTrack: Color { TachoTheme.gaugeTrack }
    public static var tachoRule: Color { TachoTheme.rule }
}

extension View {
    /// Figma Home widget surface: the light 80 % fill over a native blur material, with a soft shadow.
    /// A Liquid Glass variant rendered either too gray or too transparent next to Figma.
    func homeWidgetBackground() -> some View {
        let shape = RoundedRectangle(cornerRadius: TachoTheme.widgetRadius, style: .continuous)
        return background {
            shape.fill(.ultraThinMaterial).environment(\.colorScheme, .light)
            shape.fill(TachoTheme.widgetFill)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }
}
