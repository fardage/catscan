//
//  catscanApp.swift
//  catscan
//
//  Created by Marvin Tseng on 18.06.2026.
//

import SwiftUI

@main
struct catscanApp: App {
    /// The app-wide settings store, created once and injected down the view tree.
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
    }
}
