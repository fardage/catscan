import Vapor
import Domain

struct FlapEventDTO: Content {
    var id: UUID?
    var timestamp: Date?

    func toEntity() -> Domain.FlapEvent {
        .init(id: self.id, timestamp: self.timestamp ?? Date())
    }

    init(id: UUID? = nil, timestamp: Date? = nil) {
        self.id = id
        self.timestamp = timestamp
    }

    init(from entity: Domain.FlapEvent) {
        self.id = entity.id
        self.timestamp = entity.timestamp
    }
}
