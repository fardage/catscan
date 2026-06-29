import SwiftUI

/// Lets the user point the app at a different Catscan server, test reachability,
/// and persist the choice. The new URL takes effect once saved (see `ContentView`).
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(store: SettingsStore, viewModel: SettingsViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? SettingsViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                streamSection
                testSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.platinum)
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Settings.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Settings.save) {
                        if viewModel.save() { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        Section {
            TextField(text: $viewModel.draft, prompt: Text(verbatim: "https://example.com")) {
                Text(L10n.Settings.serverURL)
            }
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.URL)
            .onChange(of: viewModel.draft) { viewModel.draftChanged() }
        } header: {
            Text(L10n.Settings.serverURL)
        } footer: {
            if viewModel.normalizedURL == nil {
                Label {
                    Text(L10n.Settings.invalidURLFooter)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.sunlitClay)
            } else {
                Text(L10n.Settings.serverURLFooter)
            }
        }
        .listRowBackground(Color.softLinen)
    }

    private var streamSection: some View {
        Section {
            TextField(text: $viewModel.streamDraft,
                      prompt: Text(verbatim: "https://camera.example.com/live/index.m3u8")) {
                Text(L10n.Settings.streamURL)
            }
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.URL)
        } header: {
            Text(L10n.Settings.streamURL)
        } footer: {
            // The field is optional, so only warn when it has invalid content.
            if !viewModel.streamDraftIsEmpty && viewModel.normalizedStreamURL == nil {
                Label {
                    Text(L10n.Settings.invalidURLFooter)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.sunlitClay)
            } else {
                Text(L10n.Settings.streamURLFooter)
            }
        }
        .listRowBackground(Color.softLinen)
    }

    private var testSection: some View {
        Section {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                HStack {
                    Label(L10n.Settings.testConnection, systemImage: "wifi")
                    Spacer()
                    if viewModel.testState.isTesting {
                        ProgressView()
                    }
                }
            }
            .disabled(!viewModel.canTest)

            if let status = statusRow(for: viewModel.testState) {
                Label {
                    Text(status.message)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: status.symbol)
                        .foregroundStyle(status.tint)
                }
                .font(.subheadline)
            }
        }
        .listRowBackground(Color.softLinen)
    }

    // MARK: - Presentation

    /// Maps the view model's test state to the inline status row.
    private func statusRow(
        for state: SettingsViewModel.TestState
    ) -> (symbol: String, tint: Color, message: LocalizedStringKey)? {
        switch state {
        case .idle, .testing:
            return nil
        case .success(let count):
            // No green in the brand palette; `gunmetal` reads as a calm,
            // high-contrast "all good" tick (it flips light in dark mode).
            return ("checkmark.circle.fill", .gunmetal, L10n.Settings.connected(eventCount: count))
        case .failure(let message):
            // `message` is already self-describing (an unreachable host or a
            // server-side status), so don't hard-code "couldn't connect" — that
            // mislabels a server that answered with an error status.
            // `vibrantCoral` is the closest the palette has to an alert red.
            return ("xmark.circle.fill", .vibrantCoral, L10n.Settings.testFailed(message))
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(store: .preview())
}
#endif
