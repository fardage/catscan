import CatscanAPI
import OpenAPIRuntime
import OpenAPIVapor
import Domain
import Data
import Vapor
import Foundation

struct FlapEventHandler: APIProtocol {
    let app: Application

    private var repository: any FlapEventRepository {
        LiveRepositoryProvider(database: app.db).flapEvents
    }

    func listFlapEvents(_ input: Operations.listFlapEvents.Input) async throws -> Operations.listFlapEvents.Output {
        let events = try await GetFlapEventsUseCase(repository: repository).execute()
        return .ok(.init(body: .json(events.map { .init(from: $0) })))
    }

    func createFlapEvent(_ input: Operations.createFlapEvent.Input) async throws -> Operations.createFlapEvent.Output {
        guard case .json(let body) = input.body else {
            throw Abort(.badRequest)
        }
        let entity = Domain.FlapEvent(timestamp: body.timestamp ?? Date())
        let created = try await CreateFlapEventUseCase(repository: repository).execute(entity)
        return .created(.init(body: .json(.init(from: created))))
    }

    func deleteFlapEvent(_ input: Operations.deleteFlapEvent.Input) async throws -> Operations.deleteFlapEvent.Output {
        guard let id = UUID(uuidString: input.path.id) else {
            throw Abort(.badRequest)
        }
        try await DeleteFlapEventUseCase(repository: repository).execute(id: id)
        return .noContent
    }
}

extension Components.Schemas.FlapEvent {
    init(from entity: Domain.FlapEvent) {
        self.init(
            id: entity.id?.uuidString ?? "",
            timestamp: entity.timestamp,
            imagePath: entity.imagePath.map { "/images/" + URL(fileURLWithPath: $0).lastPathComponent }
        )
    }
}
