import Vapor
import Domain

/// DI seam owned by the Presentation layer: it references both Vapor
/// (`Application`/`Request`) and the Domain `RepositoryProvider`, but never the
/// concrete Data implementations. The App layer registers a factory via
/// `app.repositories.use { ... }`; controllers read `req.repositories`.
extension Application {
    public struct Repositories: Sendable {
        public typealias Factory = @Sendable (Request) -> any RepositoryProvider

        private struct FactoryStorageKey: StorageKey {
            typealias Value = Factory
        }

        private let application: Application

        init(_ application: Application) {
            self.application = application
        }

        public func use(_ factory: @escaping Factory) {
            application.storage[FactoryStorageKey.self] = factory
        }

        func provider(for request: Request) -> any RepositoryProvider {
            guard let factory = application.storage[FactoryStorageKey.self] else {
                fatalError("No RepositoryProvider factory configured. Call app.repositories.use(...) in configure.")
            }
            return factory(request)
        }
    }

    public var repositories: Repositories { .init(self) }
}

extension Request {
    public var repositories: any RepositoryProvider {
        application.repositories.provider(for: self)
    }
}
