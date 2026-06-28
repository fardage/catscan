import Foundation
import Vapor

/// Single source of truth for every filesystem path the server uses.
/// Built once from the environment in `configure(_:)` and threaded into
/// whichever subsystems need it.
struct StorageConfiguration {
    /// SQLite database file path (relative to the working directory by default).
    let databasePath: String
    /// Directory ffmpeg writes staging frames into before they are processed.
    let eventsDirectory: URL
    /// Permanent store for timestamp-named images, served as static files.
    let imagesDirectory: URL

    init(workingDirectory: String) {
        let base = URL(fileURLWithPath: workingDirectory)
        databasePath = Environment.get("DATABASE_PATH")
            ?? base.appendingPathComponent("db.sqlite").path
        eventsDirectory = Environment.get("EVENTS_DIR").map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? base.appendingPathComponent("events", isDirectory: true)
        imagesDirectory = Environment.get("IMAGES_DIR").map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? base.appendingPathComponent("Public/images", isDirectory: true)
    }
}
