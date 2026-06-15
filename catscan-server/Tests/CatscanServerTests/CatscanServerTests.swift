@testable import CatscanServer
import VaporTesting
import Testing
import Fluent
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

    /// Local mirror of the Presentation `TodoDTO` so tests can assert on HTTP
    /// payloads without that DTO leaking out of the Presentation layer.
    struct TodoPayload: Content, Equatable {
        var id: UUID?
        var title: String?
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

    @Test("Getting all the Todos")
    func getAllTodos() async throws {
        try await withApp { app in
            let repo = FluentTodoRepository(database: app.db)
            _ = try await repo.create(.init(title: "sample1"))
            _ = try await repo.create(.init(title: "sample2"))

            try await app.testing().test(.GET, "todos", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let titles = try res.content.decode([TodoPayload].self)
                    .compactMap(\.title)
                    .sorted()
                #expect(titles == ["sample1", "sample2"])
            })
        }
    }

    @Test("Creating a Todo")
    func createTodo() async throws {
        try await withApp { app in
            let newTodo = TodoPayload(id: nil, title: "test")

            try await app.testing().test(.POST, "todos", beforeRequest: { req in
                try req.content.encode(newTodo)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let stored = try await FluentTodoRepository(database: app.db).all()
                #expect(stored.map(\.title) == ["test"])
            })
        }
    }

    @Test("Deleting a Todo")
    func deleteTodo() async throws {
        try await withApp { app in
            let repo = FluentTodoRepository(database: app.db)
            let created = try await repo.create(.init(title: "test1"))
            _ = try await repo.create(.init(title: "test2"))

            try await app.testing().test(.DELETE, "todos/\(try #require(created.id))", afterResponse: { res async throws in
                #expect(res.status == .noContent)
                let remaining = try await repo.all().map(\.title)
                #expect(remaining == ["test2"])
            })
        }
    }
}
