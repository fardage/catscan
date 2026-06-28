import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    /// The editable server-URL text bound to the field.
    var draft: String
    private(set) var testState: TestState = .idle

    private let defaults: UserDefaults
    private let makeRepository: @Sendable (URL) -> any FlapEventRepository

    init(
        defaults: UserDefaults = .standard,
        makeRepository: @escaping @Sendable (URL) -> any FlapEventRepository = {
            RemoteFlapEventRepository(serverURL: $0)
        }
    ) {
        self.defaults = defaults
        self.makeRepository = makeRepository
        self.draft = defaults.string(forKey: AppEnvironment.serverURLKey) ?? ""
    }

    // MARK: - Validation

    /// The validated, normalized URL for the current draft, or `nil` if invalid.
    var normalizedURL: URL? { AppEnvironment.normalizedURL(from: draft) }

    var canSave: Bool { normalizedURL != nil }
    var canTest: Bool { normalizedURL != nil && !testState.isTesting }

    // MARK: - Actions

    /// Clears any stale test result when the user edits the field.
    func draftChanged() {
        testState = .idle
    }

    /// Persists the normalized URL. Returns `true` when saved so the caller can dismiss.
    @discardableResult
    func save() -> Bool {
        guard let url = normalizedURL else { return false }
        defaults.set(url.absoluteString, forKey: AppEnvironment.serverURLKey)
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
