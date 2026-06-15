import Vapor
import Domain

struct TodoController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let todos = routes.grouped("todos")

        todos.get(use: self.index)
        todos.post(use: self.create)
        todos.group(":todoID") { todo in
            todo.delete(use: self.delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [TodoDTO] {
        let useCase = GetTodosUseCase(repository: req.repositories.todos)
        return try await useCase.execute().map { TodoDTO(from: $0) }
    }

    @Sendable
    func create(req: Request) async throws -> TodoDTO {
        let entity = try req.content.decode(TodoDTO.self).toEntity()
        let useCase = CreateTodoUseCase(repository: req.repositories.todos)
        let created = try await useCase.execute(entity)
        return TodoDTO(from: created)
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("todoID", as: UUID.self) else {
            throw Abort(.notFound)
        }
        let useCase = DeleteTodoUseCase(repository: req.repositories.todos)
        try await useCase.execute(id: id)
        return .noContent
    }
}
