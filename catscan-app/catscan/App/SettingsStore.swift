import Foundation
import Observation

/// App-wide, observable source of truth for the handful of `UserDefaults`-backed
/// settings (the server and live-stream URLs). Views observe it for reactivity
/// and `SettingsView` writes through it, replacing the previous split between
/// `@AppStorage` in views and direct `UserDefaults` reads in `AppEnvironment`.
///
/// Injected through initializers ("constructor injection") rather than the
/// environment so each view's dependency on settings is explicit. Backed by an
/// injectable `UserDefaults` so tests and previews can use a throwaway suite.
@Observable
@MainActor
final class SettingsStore {
    /// The configured Catscan server URL (raw text). Persisted on change.
    var serverURLString: String {
        didSet { persist(serverURLString, forKey: Keys.serverURL) }
    }

    /// The configured live-stream URL (raw text), optional. Persisted on change.
    var streamURLString: String {
        didSet { persist(streamURLString, forKey: Keys.streamURL) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `didSet` doesn't fire during initialization, so seeding these from the
        // store doesn't write back.
        self.serverURLString = defaults.string(forKey: Keys.serverURL) ?? ""
        self.streamURLString = defaults.string(forKey: Keys.streamURL) ?? ""
    }

    // MARK: - Derived URLs

    /// The validated server base URL, or `nil` until a valid one is configured.
    var serverURL: URL? { AppEnvironment.normalizedURL(from: serverURLString) }

    /// The validated live-stream URL, or `nil` when unset or invalid.
    var streamURL: URL? { AppEnvironment.normalizedURL(from: streamURLString) }

    /// Resolves a server-relative `imagePath` (e.g. `/images/frame.jpg`) into an
    /// absolute URL the image loader can fetch. Returns `nil` when there's no
    /// image or no server is configured yet.
    ///
    /// Uses `appending(path:)` rather than `URL(string:relativeTo:)` so that a
    /// server configured with a sub-path (e.g. `https://host/catscan`) keeps that
    /// prefix — an absolute-path reference would otherwise replace it and point
    /// images at the host root, diverging from where the API client looks.
    func imageURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty, let base = serverURL else { return nil }
        return base.appending(path: path)
    }

    // MARK: - Persistence

    /// Writes a value, removing the key when the (trimmed) string is empty so a
    /// cleared field doesn't linger as an empty string.
    private func persist(_ value: String, forKey key: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(trimmed, forKey: key)
        }
    }

    private enum Keys {
        static let serverURL = "serverURLString"
        static let streamURL = "streamURLString"
    }
}

#if DEBUG
extension SettingsStore {
    /// A store backed by a throwaway suite for previews, optionally pre-configured.
    static func preview(serverURL: String = "", streamURL: String = "") -> SettingsStore {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)")!)
        store.serverURLString = serverURL
        store.streamURLString = streamURL
        return store
    }
}
#endif
