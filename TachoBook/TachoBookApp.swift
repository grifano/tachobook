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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
