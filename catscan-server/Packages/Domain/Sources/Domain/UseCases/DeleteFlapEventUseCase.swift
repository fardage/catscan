import struct Foundation.UUID

/// Deletes the flap event with the given id.
public struct DeleteFlapEventUseCase: Sendable {
    private let repository: any FlapEventRepository

    public init(repository: any FlapEventRepository) {
        self.repository = repository
    }

    public func execute(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}
