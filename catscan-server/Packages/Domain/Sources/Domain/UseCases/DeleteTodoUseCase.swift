import struct Foundation.UUID

/// Deletes the todo with the given id.
public struct DeleteTodoUseCase: Sendable {
    private let repository: any TodoRepository

    public init(repository: any TodoRepository) {
        self.repository = repository
    }

    public func execute(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}
