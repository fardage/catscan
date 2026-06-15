import Fluent
import Domain

/// Live `RepositoryProvider` that hands out Fluent-backed repositories for a
/// given database connection. Constructed per request by the App layer.
public struct LiveRepositoryProvider: RepositoryProvider {
    private let database: any Database

    public init(database: any Database) {
        self.database = database
    }

    public var todos: any TodoRepository {
        FluentTodoRepository(database: database)
    }
}
