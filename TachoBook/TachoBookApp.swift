//
//  TachoBookApp.swift
//  TachoBook
//
//  Created by sorlenko on 07/10/2026.
//

import SwiftUI

@main
struct TachoBookApp: App {
    init() {
        // Work/Rest switch text: dark navy (Labels/Primary) selected or not, in Light and Dark mode.
        let navy = UIColor(Color.tachoTextOnLight)
        for state in [UIControl.State.normal, .selected] {
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: navy], for: state)
        }

        // Tab bar: the disabled tabs (Violations, Restrictions) are white like the active ones,
        // not dimmed (Serhii, 2026-10-20). They stay disabled: a tap does nothing.
        let white = UIColor(Color.tachoTextOnDark)
        let item = UITabBarItemAppearance()
        for state in [item.normal, item.selected, item.disabled, item.focused] {
            state.iconColor = white
            state.titleTextAttributes = [.foregroundColor: white]
        }
        let tabBar = UITabBarAppearance()
        tabBar.configureWithDefaultBackground()
        tabBar.stackedLayoutAppearance = item
        tabBar.inlineLayoutAppearance = item
        tabBar.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
