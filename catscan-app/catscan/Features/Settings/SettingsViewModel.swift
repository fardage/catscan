import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    /// The editable server-URL text bound to the field.
    var draft: String
    /// The editable live-stream URL text. Optional, so an empty value is valid.
    var streamDraft: String
    private(set) var testState: TestState = .idle

    private let store: SettingsStore
    private let makeRepository: @MainActor (URL) -> any FlapEventRepository

    init(
        store: SettingsStore,
        makeRepository: @escaping @MainActor (URL) -> any FlapEventRepository = {
            RemoteFlapEventRepository(serverURL: $0)
        }
    ) {
        self.store = store
        self.makeRepository = makeRepository
        self.draft = store.serverURLString
        self.streamDraft = store.streamURLString
    }

    // MARK: - Validation

    /// The validated, normalized URL for the current draft, or `nil` if invalid.
    var normalizedURL: URL? { AppEnvironment.normalizedURL(from: draft) }

    /// The normalized live-stream URL, or `nil` when the field is empty or invalid.
    var normalizedStreamURL: URL? { AppEnvironment.normalizedURL(from: streamDraft) }

    /// Whether the (optional) stream field is empty after trimming whitespace.
    var streamDraftIsEmpty: Bool {
        streamDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // The server URL is required; the stream URL is optional but, when present,
    // must be valid.
    var canSave: Bool { normalizedURL != nil && (streamDraftIsEmpty || normalizedStreamURL != nil) }
    var canTest: Bool { normalizedURL != nil && !testState.isTesting }

    // MARK: - Actions

    /// Clears any stale test result when the user edits the field.
    func draftChanged() {
        testState = .idle
    }

    /// Persists the normalized server URL and the optional stream URL. Returns
    /// `true` when saved so the caller can dismiss.
    @discardableResult
    func save() -> Bool {
        guard let url = normalizedURL else { return false }
        store.serverURLString = url.absoluteString
        // An empty stream field clears the setting (hides the dashboard's live
        // card; the store drops emptied values from `UserDefaults`). A non-empty
        // but invalid draft leaves the stored value untouched rather than wiping it.
        if streamDraftIsEmpty {
            store.streamURLString = ""
        } else if let streamURL = normalizedStreamURL {
            store.streamURLString = streamURL.absoluteString
        }
        return true
    }

    /// Builds a repository for the current draft and checks it can be reached.
    func testConnection() async {
        guard let url = normalizedURL else { return }
        testState = .testing
        do {
            let count = try await makeRepository(url).checkConnection()
            // The user may have edited the field while the request was in flight;
            // only apply the result if it still describes the current draft.
            guard normalizedURL == url else { return }
            testState = .success(count)
        } catch {
            guard normalizedURL == url else { return }
            testState = .failure((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    // MARK: - Test state

    enum TestState {
        case idle
        case testing
        case success(Int)
        case failure(String)

        var isTesting: Bool { if case .testing = self { return true }; return false }
    }
}
