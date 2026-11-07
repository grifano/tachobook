//
//  ContentView.swift
//  TachoBook
//
//  Created by sorlenko on 07/10/2026.
//

import SwiftUI

/// Figma "Main Tab Bar" (node 490:26372): Home, History, Violations, Restrictions. Home, History and Violations
/// work; Restrictions is visible, and a tap does nothing. SwiftUI does not expose it to accessibility as disabled
/// (no "not enabled" trait), which Serhii accepted on 2026-10-20 (option A); the UI tests exclude exactly that audit
/// issue (see AccessibilityAuditSupport).
/// SF Symbols as in Figma: house, calendar.badge.clock, exclamationmark.circle.fill, globe.badge.clock.fill.
struct ContentView: View {
    enum MainTab: Hashable {
        case home
        case history
        case violations
        case restrictions
    }

    /// One model for every tab, so History and Violations follow every change made on Home.
    @State private var model = DayLogModel.dashboardModel()
    @State private var selection = ContentView.initialTab

    /// DEBUG only: `-startTab violations` opens the Violations tab, for screenshots and audits.
    private static var initialTab: MainTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-startTab"), index + 1 < args.count {
            switch args[index + 1] {
            case "history": return .history
            case "violations": return .violations
            default: break
            }
        }
        #endif
        return .home
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: MainTab.home) {
                DashboardView(model: model)
            }
            Tab("History", systemImage: "calendar.badge.clock", value: MainTab.history) {
                // A day with several violations opens the Violations list (decision 20).
                HistoryView(model: model, onOpenViolations: { selection = .violations })
            }
            Tab("Violations", systemImage: "exclamationmark.circle.fill", value: MainTab.violations) {
                ViolationsView(model: model)
            }
            Tab("Restrictions", systemImage: "globe.badge.clock.fill", value: MainTab.restrictions) {
                Color.clear
            }
            .disabled(true)
        }
        // Standard Apple tab bar with white icons and labels in Light and Dark mode, the selected Home tab
        // included (Serhii, 2026-10-20): the dark colour scheme makes the system draw white content, the
        // white tint keeps the selected tab white, and the system's own selection highlight marks Home.
        .tint(Color.tachoTextOnDark)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

#Preview {
    ContentView()
}
