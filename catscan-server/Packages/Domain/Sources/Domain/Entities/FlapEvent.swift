import struct Foundation.UUID
import struct Foundation.Date

/// A pure domain entity representing a single cat-flap observation, free of any
/// persistence or transport concerns. For now it carries only the moment the
/// event was detected.
public struct FlapEvent: Sendable, Equatable {
    public let id: UUID?
    public let timestamp: Date

    public init(id: UUID? = nil, timestamp: Date) {
        self.id = id
        self.timestamp = timestamp
    }
}
