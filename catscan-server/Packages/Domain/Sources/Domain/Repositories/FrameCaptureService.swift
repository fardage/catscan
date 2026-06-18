/// Abstraction over the camera feed. Implemented by the Data layer; the
/// dependency rule keeps Domain unaware of how frames are produced (ffmpeg,
/// a fixture directory, a fake, …).
public protocol FrameCaptureService: Sendable {
    /// Begins capturing and yields each detected frame as it becomes available.
    ///
    /// The capture runs until the consumer stops iterating (or cancels the
    /// surrounding task), at which point the underlying source is torn down. The
    /// stream finishes by throwing if the source fails.
    func capture() -> AsyncThrowingStream<CapturedFrame, any Error>
}
