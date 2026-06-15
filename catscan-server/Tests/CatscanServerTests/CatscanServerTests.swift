@testable import CatscanServer
import VaporTesting
import Testing
import Fluent
import Foundation
import Domain
import Data

@Suite("App Tests with DB", .serialized)
struct CatscanServerTests {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    /// Local mirror of the Presentation `FlapEventDTO` so tests can assert on
    /// HTTP payloads without that DTO leaking out of the Presentation layer.
    struct FlapEventPayload: Content, Equatable {
        var id: UUID?
        var timestamp: Date?
    }

    @Test("Test Hello World Route")
    func helloWorld() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "hello", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Hello, world!")
            })
        }
    }

    @Test("Getting all the flap events")
    func getAllFlapEvents() async throws {
        try await withApp { app in
            let repo = FluentFlapEventRepository(database: app.db)
            _ = try await repo.create(.init(timestamp: Date()))
            _ = try await repo.create(.init(timestamp: Date()))

            try await app.testing().test(.GET, "flap-events", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let events = try res.content.decode([FlapEventPayload].self)
                #expect(events.count == 2)
            })
        }
    }

    @Test("Creating a flap event")
    func createFlapEvent() async throws {
        try await withApp { app in
            let newEvent = FlapEventPayload(id: nil, timestamp: Date())

            try await app.testing().test(.POST, "flap-events", beforeRequest: { req in
                try req.content.encode(newEvent)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let stored = try await FluentFlapEventRepository(database: app.db).all()
                #expect(stored.count == 1)
            })
        }
    }

    @Test("Deleting a flap event")
    func deleteFlapEvent() async throws {
        try await withApp { app in
            let repo = FluentFlapEventRepository(database: app.db)
            let created = try await repo.create(.init(timestamp: Date()))
            _ = try await repo.create(.init(timestamp: Date()))

            try await app.testing().test(.DELETE, "flap-events/\(try #require(created.id))", afterResponse: { res async throws in
                #expect(res.status == .noContent)
                let remaining = try await repo.all()
                #expect(remaining.count == 1)
                #expect(remaining.first?.id != created.id)
            })
        }
    }
}
