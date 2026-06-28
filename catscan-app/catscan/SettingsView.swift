import SwiftUI

/// Lets the user point the app at a different Catscan server, test reachability,
/// and persist the choice. The new URL takes effect once saved (see `ContentView`).
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(viewModel: SettingsViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? SettingsViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                testSection
            }
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
                Text("Server URL")
            }
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.URL)
            .onChange(of: viewModel.draft) { viewModel.draftChanged() }
        } header: {
            Text("Server URL")
        } footer: {
            if viewModel.normalizedURL == nil {
                Label {
                    Text(verbatim: "Enter a valid URL, e.g. https://catscan.example.com")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.orange)
            } else {
                Text("The address of your Catscan server. Flap events and snapshots are loaded from here.")
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                HStack {
                    Label("Test Connection", systemImage: "wifi")
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
            return ("checkmark.circle.fill", .green, "Connected · ^[\(count) event](inflect: true)")
        case .failure(let message):
            // `message` is already self-describing (an unreachable host or a
            // server-side status), so don't hard-code "couldn't connect" — that
            // mislabels a server that answered with an error status.
            return ("xmark.circle.fill", .red, "Test failed. \(message)")
        }
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
