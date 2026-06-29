import SwiftUI
import CatscanAPI

/// Convenience alias so views don't have to spell out the generated type.
typealias FlapEvent = Components.Schemas.FlapEvent

/// Single source of truth for app-wide configuration.
enum AppEnvironment {
    /// `UserDefaults` key under which the user's configured server URL is stored.
    static let serverURLKey = "serverURLString"

    /// Base URL of the Catscan server, or `nil` until the user configures one.
    /// The repository and image loading both resolve against this.
    static var serverURL: URL? {
        guard let stored = UserDefaults.standard.string(forKey: serverURLKey) else { return nil }
        return normalizedURL(from: stored)
    }

    /// Resolves a server-relative `imagePath` (e.g. `/images/frame.jpg`) into an
    /// absolute URL the image loader can fetch. Returns `nil` when there's no
    /// image or no server is configured yet.
    ///
    /// Uses `appending(path:)` rather than `URL(string:relativeTo:)` so that a
    /// server configured with a sub-path (e.g. `https://host/catscan`) keeps that
    /// prefix — an absolute-path reference would otherwise replace it and point
    /// images at the host root, diverging from where the API client looks.
    static func imageURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty, let base = serverURL else { return nil }
        return base.appending(path: path)
    }

    /// Validates and normalizes a user-entered server URL: trims whitespace,
    /// prepends `https://` when no scheme is present, and requires a host.
    /// Returns `nil` for anything that can't be a usable server URL.
    static func normalizedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme),
              let host = url.host(), !host.isEmpty else { return nil }
        return url
    }
}

extension View {
    /// Grouped card: rounded, filled with `softLinen` (a warm near-white) so it
    /// lifts off the slightly darker `platinum` grey screen base — the same
    /// white-card-on-grey relationship UIKit's grouped backgrounds use, in both
    /// light and dark appearances.
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        background(
            Color.softLinen,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    /// Screen base: the `platinum` grey grouped background that `cardStyle`
    /// cards lift off of. Centralized so the app's screens can't drift apart.
    func screenBackground() -> some View {
        background(Color.platinum)
    }
}
