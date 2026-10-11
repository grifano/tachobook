//
//  DashboardTabBarView.swift
//  TachoBook
//

import SwiftUI

public struct DashboardTabBarView: View {
    @ScaledMetric(relativeTo: .caption2) private var tabLabelSize: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var tabIconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var tabIconHeight: CGFloat = 28

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            tabLabel("Home", symbol: "house", isSelected: true)
            tabLabel("History", symbol: "calendar.badge.clock")
            tabLabel("Violations", symbol: "exclamationmark.circle.fill")
            tabLabel("Restrictions", symbol: "globe.badge.clock.fill")
        }
        .padding(4)
        // Let the system render the optical glass, edge lighting, and shadow.
        // The orange selection remains a solid fill, as specified in Figma.
        .glassEffect(.clear, in: Capsule())
        .background(.black.opacity(0.2), in: Capsule())
        .padding(.horizontal, 21)
        .padding(.top, 12)
    }

    private func tabLabel(_ title: String, symbol: String, isSelected: Bool = false) -> some View {
        VStack(spacing: 1) {
            Image(systemName: symbol)
                .font(.system(size: tabIconSize, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(height: tabIconHeight)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: tabLabelSize, weight: .semibold))
                .tracking(-0.1)
        }
        .foregroundStyle(.white)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                Capsule().fill(Color.tachoOrange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
