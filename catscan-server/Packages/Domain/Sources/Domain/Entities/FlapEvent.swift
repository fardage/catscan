import struct Foundation.UUID
import struct Foundation.Date

/// A pure domain entity representing a single cat-flap observation, free of any
/// persistence or transport concerns.
public struct FlapEvent: Sendable, Equatable {
    public let id: UUID?
    public let timestamp: Date
    /// Absolute path of the associated JPEG in the images directory.
    public let imagePath: String?

    public init(id: UUID? = nil, timestamp: Date, imagePath: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.imagePath = imagePath
    }
}
