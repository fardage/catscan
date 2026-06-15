import Vapor
import Domain

struct TodoDTO: Content {
    var id: UUID?
    var title: String?

    func toEntity() -> Domain.Todo {
        .init(id: self.id, title: self.title ?? "")
    }

    init(id: UUID? = nil, title: String? = nil) {
        self.id = id
        self.title = title
    }

    init(from entity: Domain.Todo) {
        self.id = entity.id
        self.title = entity.title
    }
}
