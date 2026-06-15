/// Persists a new todo and returns the stored entity.
public struct CreateTodoUseCase: Sendable {
    private let repository: any TodoRepository

    public init(repository: any TodoRepository) {
        self.repository = repository
    }

    public func execute(_ todo: Todo) async throws -> Todo {
        try await repository.create(todo)
    }
}
