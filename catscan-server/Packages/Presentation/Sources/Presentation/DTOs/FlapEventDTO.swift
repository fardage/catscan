import Vapor
import Domain

struct FlapEventDTO: Content {
    var id: UUID?
    var timestamp: Date?
    var imagePath: String?

    func toEntity() -> Domain.FlapEvent {
        .init(id: self.id, timestamp: self.timestamp ?? Date(), imagePath: self.imagePath)
    }

    init(id: UUID? = nil, timestamp: Date? = nil, imagePath: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.imagePath = imagePath
    }

    init(from entity: Domain.FlapEvent) {
        self.id = entity.id
        self.timestamp = entity.timestamp
        self.imagePath = entity.imagePath
    }
}
