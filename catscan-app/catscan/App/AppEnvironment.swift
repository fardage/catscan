import SwiftUI
import CatscanAPI

/// Convenience alias so views don't have to spell out the generated type.
typealias FlapEvent = Components.Schemas.FlapEvent

/// App-wide configuration helpers. URL-backed settings now live in
/// `SettingsStore`; what remains here is the pure URL normalization used by both
/// the store and the settings editor.
enum AppEnvironment {
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
