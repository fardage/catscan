import Vapor
import Domain

struct FlapEventController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let flapEvents = routes.grouped("flap-events")

        flapEvents.get(use: self.index)
        flapEvents.post(use: self.create)
        flapEvents.group(":flapEventID") { flapEvent in
            flapEvent.delete(use: self.delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [FlapEventDTO] {
        let useCase = GetFlapEventsUseCase(repository: req.repositories.flapEvents)
        return try await useCase.execute().map { FlapEventDTO(from: $0) }
    }

    @Sendable
    func create(req: Request) async throws -> FlapEventDTO {
        let entity = try req.content.decode(FlapEventDTO.self).toEntity()
        let useCase = CreateFlapEventUseCase(repository: req.repositories.flapEvents)
        let created = try await useCase.execute(entity)
        return FlapEventDTO(from: created)
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("flapEventID", as: UUID.self) else {
            throw Abort(.notFound)
        }
        let useCase = DeleteFlapEventUseCase(repository: req.repositories.flapEvents)
        try await useCase.execute(id: id)
        return .noContent
    }
}
