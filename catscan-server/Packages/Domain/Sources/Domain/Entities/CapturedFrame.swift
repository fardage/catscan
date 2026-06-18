import struct Foundation.URL
import struct Foundation.Date

/// A pure domain entity representing a single still frame extracted from the
/// camera feed, free of any capture or transport concerns. It records where the
/// frame was written and when it was observed.
public struct CapturedFrame: Sendable, Equatable {
    /// Location of the frame on disk.
    public let url: URL
    /// Sequence number parsed from the frame's filename, when available.
    public let index: Int?
    /// The moment the frame was observed by the capturer.
    public let detectedAt: Date

    public init(url: URL, index: Int? = nil, detectedAt: Date) {
        self.url = url
        self.index = index
        self.detectedAt = detectedAt
    }
}
