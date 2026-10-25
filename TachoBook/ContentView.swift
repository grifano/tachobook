//
//  ContentView.swift
//  TachoBook
//
//  Created by sorlenko on 07/10/2026.
//

import SwiftUI

/// Figma "Main Tab Bar" (node 490:26372): Home, History, Violations, Restrictions. Home and History work;
/// Violations and Restrictions are visible, and a tap does nothing. SwiftUI does not expose them to
/// accessibility as disabled (no "not enabled" trait), which Serhii accepted on 2026-10-20 (option A);
/// the UI tests exclude exactly that audit issue (see AccessibilityAuditSupport).
/// SF Symbols as in Figma: house, calendar.badge.clock, exclamationmark.circle.fill, globe.badge.clock.fill.
struct ContentView: View {
    /// One model for Home and History, so the calendar follows every change made on Home.
    @State private var model = DayLogModel.dashboardModel()

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                DashboardView(model: model)
            }
            Tab("History", systemImage: "calendar.badge.clock") {
                HistoryView(model: model)
            }
            Tab("Violations", systemImage: "exclamationmark.circle.fill") {
                Color.clear
            }
            .disabled(true)
            Tab("Restrictions", systemImage: "globe.badge.clock.fill") {
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
