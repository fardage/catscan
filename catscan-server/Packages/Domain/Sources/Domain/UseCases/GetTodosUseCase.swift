/// Returns every todo.
public struct GetTodosUseCase: Sendable {
    private let repository: any TodoRepository

    public init(repository: any TodoRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [Todo] {
        try await repository.all()
    }
}
