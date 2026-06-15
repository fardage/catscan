import struct Foundation.UUID

/// A pure domain entity representing a todo item, free of any persistence or
/// transport concerns.
public struct Todo: Sendable, Equatable {
    public let id: UUID?
    public let title: String

    public init(id: UUID? = nil, title: String) {
        self.id = id
        self.title = title
    }
}
