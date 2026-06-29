//
//  ContentView.swift
//  catscan
//
//  Created by Marvin Tseng on 18.06.2026.
//

import SwiftUI

struct ContentView: View {
    let settings: SettingsStore
    @State private var showingSettings = false

    var body: some View {
        if let url = settings.serverURL {
            // Rebuild the dashboard (and its view model / repository) whenever the
            // configured server changes, so data reloads from the new URL.
            DashboardView(
                viewModel: FlapEventsViewModel(
                    repository: RemoteFlapEventRepository(serverURL: url),
                    settings: settings
                )
            )
            .id(settings.serverURLString)
        } else {
            unconfigured
        }
    }

    private var unconfigured: some View {
        ContentUnavailableView {
            Label(L10n.Unconfigured.title, systemImage: "server.rack")
        } description: {
            Text(L10n.Unconfigured.description)
        } actions: {
            Button(L10n.Unconfigured.configure) { showingSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: settings)
        }
    }
}

#Preview {
    ContentView(settings: .preview(serverURL: "https://catscan.example.com"))
}
