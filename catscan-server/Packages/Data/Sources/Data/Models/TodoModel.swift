import Fluent
import Domain
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class TodoModel: Model, @unchecked Sendable {
    static let schema = "todos"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    init() { }

    init(id: UUID? = nil, title: String) {
        self.id = id
        self.title = title
    }

    convenience init(from entity: Domain.Todo) {
        self.init(id: entity.id, title: entity.title)
    }

    func toEntity() -> Domain.Todo {
        .init(id: self.id, title: self.title)
    }
}
