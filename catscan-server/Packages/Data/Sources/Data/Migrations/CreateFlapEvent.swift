import Fluent

public struct CreateFlapEvent: AsyncMigration {
    public init() {}

    public func prepare(on database: any Database) async throws {
        try await database.schema("flap_events")
            .id()
            .field("timestamp", .datetime, .required)
            .create()
    }

    public func revert(on database: any Database) async throws {
        try await database.schema("flap_events").delete()
    }
}
