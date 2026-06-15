import NIOSSL
import Fluent
import FluentSQLiteDriver
import Vapor
import Data
import Presentation

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(CreateTodo())

    // wire the Data layer's concrete repositories into the Presentation seam
    app.repositories.use { req in
        LiveRepositoryProvider(database: req.db)
    }

    // register routes
    try routes(app)
}
