import Fluent
import Domain
import struct Foundation.UUID

/// Fluent-backed implementation of `TodoRepository`, bound to a single database
/// connection (typically `req.db`).
public struct FluentTodoRepository: TodoRepository {
    private let database: any Database

    public init(database: any Database) {
        self.database = database
    }

    public func all() async throws -> [Todo] {
        try await TodoModel.query(on: database).all().map { $0.toEntity() }
    }

    public func create(_ todo: Todo) async throws -> Todo {
        let model = TodoModel(from: todo)
        try await model.save(on: database)
        return model.toEntity()
    }

    public func delete(id: UUID) async throws {
        try await TodoModel.query(on: database)
            .filter(\.$id == id)
            .delete()
    }
}
