import NIOSSL
import Fluent
import FluentSQLiteDriver
import Vapor
import Data
import Presentation
import OpenAPIVapor
import CatscanAPI

// configures your application
public func configure(_ app: Application) async throws {
    let storage = StorageConfiguration(workingDirectory: app.directory.workingDirectory)

    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.sqlite(.file(storage.databasePath)), as: .sqlite)

    app.migrations.add(CreateFlapEvent())

    // wire the Data layer's concrete repositories into the Presentation seam
    app.repositories.use { req in
        LiveRepositoryProvider(database: req.db)
    }

    // Camera capture only runs when CAMERA_RTSP_URL is configured, so tests and
    // local runs don't spawn a subprocess.
    if let source = Environment.get("CAMERA_RTSP_URL") {
        try await app.autoMigrate()
        app.lifecycle.use(FrameCaptureLifecycleHandler(configuration: FFmpegCaptureConfiguration(
            source: source,
            outputDirectory: storage.eventsDirectory,
            imagesDirectory: storage.imagesDirectory,
            executableName: Environment.get("FFMPEG_PATH") ?? "ffmpeg"
        )))
    }

    // Register OpenAPI routes
    let transport = VaporTransport(routesBuilder: app)
    try FlapEventHandler(app: app).registerHandlers(on: transport, serverURL: Servers.Server1.url())
}
