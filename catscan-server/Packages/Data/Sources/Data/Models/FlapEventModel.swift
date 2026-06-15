import Fluent
import Domain
import struct Foundation.UUID
import struct Foundation.Date

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class FlapEventModel: Model, @unchecked Sendable {
    static let schema = "flap_events"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "timestamp")
    var timestamp: Date

    init() { }

    init(id: UUID? = nil, timestamp: Date) {
        self.id = id
        self.timestamp = timestamp
    }

    convenience init(from entity: Domain.FlapEvent) {
        self.init(id: entity.id, timestamp: entity.timestamp)
    }

    func toEntity() -> Domain.FlapEvent {
        .init(id: self.id, timestamp: self.timestamp)
    }
}
