import NIOSSL
import Fluent
import FluentSQLiteDriver
import Vapor
import Data
import Presentation

private extension Environment {
    static var cameraRTSPURL: String? {
        Self.get("CAMERA_RTSP_URL")
    }
    static var eventsDir: String? {
        Self.get("EVENTS_DIR")
    }
    static var imagesDir: String? {
        Self.get("IMAGES_DIR")
    }
    static var ffmpegPath: String? {
        Self.get("FFMPEG_PATH")
    }
}

// configures your application
public func configure(_ app: Application) async throws {
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(CreateFlapEvent())

    // wire the Data layer's concrete repositories into the Presentation seam
    app.repositories.use { req in
        LiveRepositoryProvider(database: req.db)
    }

    // Camera capture only runs when CAMERA_RTSP_URL is configured, so tests and
    // local runs don't spawn a subprocess.
    if let source = Environment.cameraRTSPURL {
        try await app.autoMigrate()
        app.lifecycle.use(FrameCaptureLifecycleHandler(configuration: frameCaptureConfiguration(app, source: source)))
    }

    // register routes
    try routes(app)
}

/// Builds the capture configuration from the environment. The output directory
/// defaults to `<workingDirectory>/events` (`/app/events` in the container, which
/// the `vapor` user can write) and can be overridden with `EVENTS_DIR`.
private func frameCaptureConfiguration(_ app: Application, source: String) -> FFmpegCaptureConfiguration {
    let workingDir = URL(fileURLWithPath: app.directory.workingDirectory)
    let outputDirectory = Environment.eventsDir.map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? workingDir.appendingPathComponent("events", isDirectory: true)
    let imagesDirectory = Environment.imagesDir.map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? workingDir.appendingPathComponent("Public/images", isDirectory: true)

    return FFmpegCaptureConfiguration(
        source: source,
        outputDirectory: outputDirectory,
        imagesDirectory: imagesDirectory,
        executableName: Environment.ffmpegPath ?? "ffmpeg"
    )
}
