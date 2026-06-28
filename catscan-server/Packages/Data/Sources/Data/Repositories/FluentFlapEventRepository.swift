import Fluent
import Domain
import struct Foundation.UUID

/// Fluent-backed implementation of `FlapEventRepository`, bound to a single
/// database connection (typically `req.db`).
public struct FluentFlapEventRepository: FlapEventRepository {
    private let database: any Database

    public init(database: any Database) {
        self.database = database
    }

    public func all() async throws -> [FlapEvent] {
        try await FlapEventModel.query(on: database)
            .sort(\.$timestamp, .descending)
            .all()
            .map { $0.toEntity() }
    }

    public func create(_ event: FlapEvent) async throws -> FlapEvent {
        let model = FlapEventModel(from: event)
        try await model.save(on: database)
        return model.toEntity()
    }

    public func delete(id: UUID) async throws {
        try await FlapEventModel.query(on: database)
            .filter(\.$id == id)
            .delete()
    }
}
