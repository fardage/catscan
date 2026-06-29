import SwiftUI

/// Type-safe references to every user-facing string in the app.
///
/// Each value is the key looked up in `Localizable.xcstrings`. Centralizing them
/// here — instead of scattering string literals through the views — gives one
/// place to audit copy and keeps the views and the string catalog from drifting
/// apart. Keys are grouped by the screen that uses them; a few cross-cutting ones
/// live in `Common`.
///
/// `LocalizedStringKey` is used throughout because every SwiftUI control that
/// shows text (`Text`, `Label`, `Button`, `navigationTitle`, section headers, …)
/// accepts it, and it supports interpolation and automatic grammar agreement for
/// the count-dependent strings below.
enum L10n {

    enum Dashboard {
        static let title: LocalizedStringKey = "Summary"
        static let refresh: LocalizedStringKey = "Refresh"
        static let serverSettings: LocalizedStringKey = "Server Settings"
        static let recentActivity: LocalizedStringKey = "Recent Activity"
        static let showAll: LocalizedStringKey = "Show All"

        static let statToday: LocalizedStringKey = "Today"
        static let statThisWeek: LocalizedStringKey = "This Week"
        static let statTotal: LocalizedStringKey = "Total"

        static let loadingActivity: LocalizedStringKey = "Loading recent activity…"
        static let activityUnreachable: LocalizedStringKey = "Couldn't reach your Catscan server. Pull to refresh to try again."
        static let noActivity: LocalizedStringKey = "No flap events yet. They'll appear here as your cat comes and goes."

        static let latestSnapshot: LocalizedStringKey = "Latest Snapshot"
        static let lastSeen: LocalizedStringKey = "Last seen"

        static let snapshotLoading: LocalizedStringKey = "Loading…"
        static let snapshotLoadFailed: LocalizedStringKey = "Couldn't load snapshot"
        static let noSnapshots: LocalizedStringKey = "No snapshots yet"

        /// Unit caption shown beneath a stat's count; the number itself is
        /// rendered separately, so only the noun is localized here.
        static func visitUnit(_ count: Int) -> LocalizedStringKey {
            count == 1 ? "visit" : "visits"
        }
    }

    enum Activity {
        static let title: LocalizedStringKey = "Activity"
        static let emptyTitle: LocalizedStringKey = "No Activity"
        static let failedTitle: LocalizedStringKey = "Couldn't Load Activity"
        static let emptyDescription: LocalizedStringKey = "Flap events will appear here as your cat comes and goes."
        static let failedDescription: LocalizedStringKey = "We couldn't reach your Catscan server. Pull to refresh to try again."

        /// "3 visits" day-section count, grammatically inflected per language.
        static func visitCount(_ count: Int) -> LocalizedStringKey {
            "^[\(count) visit](inflect: true)"
        }
    }

    enum EventDetail {
        static let title: LocalizedStringKey = "Flap Event"
        static let date: LocalizedStringKey = "Date"
        static let time: LocalizedStringKey = "Time"
        static let captured: LocalizedStringKey = "Captured"
        static let snapshot: LocalizedStringKey = "Snapshot"
        static let eventID: LocalizedStringKey = "Event ID"
        static let snapshotAvailable: LocalizedStringKey = "Available"
        static let snapshotNone: LocalizedStringKey = "None"
    }

    enum Settings {
        static let title: LocalizedStringKey = "Server Settings"
        static let cancel: LocalizedStringKey = "Cancel"
        static let save: LocalizedStringKey = "Save"
        static let serverURL: LocalizedStringKey = "Server URL"
        static let serverURLFooter: LocalizedStringKey = "The address of your Catscan server. Flap events and snapshots are loaded from here."
        static let invalidURLFooter: LocalizedStringKey = "Enter a valid URL, e.g. https://catscan.example.com"
        static let testConnection: LocalizedStringKey = "Test Connection"

        /// "Connected · 5 events" success status, count inflected per language.
        static func connected(eventCount: Int) -> LocalizedStringKey {
            "Connected · ^[\(eventCount) event](inflect: true)"
        }

        /// "Test failed. <reason>" — `message` is an already-localized,
        /// self-describing error description supplied at runtime.
        static func testFailed(_ message: String) -> LocalizedStringKey {
            "Test failed. \(message)"
        }
    }

    enum Unconfigured {
        static let title: LocalizedStringKey = "No Server Configured"
        static let description: LocalizedStringKey = "Add your Catscan server's address to start seeing your cat's flap events."
        static let configure: LocalizedStringKey = "Configure Server"
    }

    enum Common {
        static let today: LocalizedStringKey = "Today"
        static let yesterday: LocalizedStringKey = "Yesterday"
    }
}
