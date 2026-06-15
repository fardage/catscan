/// Persists a new flap event and returns the stored entity.
public struct CreateFlapEventUseCase: Sendable {
    private let repository: any FlapEventRepository

    public init(repository: any FlapEventRepository) {
        self.repository = repository
    }

    public func execute(_ event: FlapEvent) async throws -> FlapEvent {
        try await repository.create(event)
    }
}
