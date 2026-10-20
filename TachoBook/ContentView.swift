//
//  ContentView.swift
//  TachoBook
//
//  Created by sorlenko on 07/10/2026.
//

import SwiftUI

/// Figma "Main Tab Bar" (node 490:26372): Home, History, Violations, Restrictions. Only Home exists so
/// far; the other tabs are visible and dimmed, and a tap does nothing. SwiftUI does not expose them to
/// accessibility as disabled (no "not enabled" trait), which Serhii accepted on 2026-10-20 (option A).
/// SF Symbols as in Figma: house, calendar.badge.clock, exclamationmark.circle.fill, globe.badge.clock.fill.
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                DashboardView()
            }
            Tab("History", systemImage: "calendar.badge.clock") {
                Color.clear
            }
            .disabled(true)
            Tab("Violations", systemImage: "exclamationmark.circle.fill") {
                Color.clear
            }
            .disabled(true)
            Tab("Restrictions", systemImage: "globe.badge.clock.fill") {
                Color.clear
            }
            .disabled(true)
        }
        // Figma selection fill: #E8652A.
        .tint(.tachoOrange)
    }
}

#Preview {
    ContentView()
}
