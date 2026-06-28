//
//  ContentView.swift
//  catscan
//
//  Created by Marvin Tseng on 18.06.2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(AppEnvironment.serverURLKey)
    private var serverURLString = ""
    @State private var showingSettings = false

    var body: some View {
        if let url = AppEnvironment.normalizedURL(from: serverURLString) {
            // Rebuild the dashboard (and its view model / repository) whenever the
            // configured server changes, so data reloads from the new URL.
            DashboardView(
                viewModel: FlapEventsViewModel(repository: RemoteFlapEventRepository(serverURL: url))
            )
            .id(serverURLString)
        } else {
            unconfigured
        }
    }

    private var unconfigured: some View {
        ContentUnavailableView {
            Label("No Server Configured", systemImage: "server.rack")
        } description: {
            Text("Add your Catscan server's address to start seeing your cat's flap events.")
        } actions: {
            Button("Configure Server") { showingSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
}
