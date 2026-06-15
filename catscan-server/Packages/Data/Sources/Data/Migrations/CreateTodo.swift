import Fluent

public struct CreateTodo: AsyncMigration {
    public init() {}

    public func prepare(on database: any Database) async throws {
        try await database.schema("todos")
            .id()
            .field("title", .string, .required)
            .create()
    }

    public func revert(on database: any Database) async throws {
        try await database.schema("todos").delete()
    }
}
