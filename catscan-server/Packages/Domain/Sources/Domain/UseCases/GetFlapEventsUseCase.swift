/// Returns every recorded flap event.
public struct GetFlapEventsUseCase: Sendable {
    private let repository: any FlapEventRepository

    public init(repository: any FlapEventRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [FlapEvent] {
        try await repository.all()
    }
}
