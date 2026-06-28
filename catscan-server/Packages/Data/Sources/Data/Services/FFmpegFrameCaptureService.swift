import Domain
import Subprocess
import Foundation

/// `FrameCaptureService` backed by an ffmpeg child process. ffmpeg pulls the
/// RTSP feed, applies the scene-change filter, and writes JPEG frames into the
/// configured output directory; this service runs that process and surfaces each
/// completed frame file as a `CapturedFrame`.
///
/// ffmpeg does not stream frames over a pipe here — it writes files — so the
/// process is run for its lifecycle while a poller watches the directory. The
/// two run concurrently; whichever ends first (ffmpeg exiting, or the consumer
/// cancelling) tears the other down. On cancellation swift-subprocess sends
/// `SIGTERM` then `SIGKILL` per the configured teardown sequence.
public struct FFmpegFrameCaptureService: FrameCaptureService {
    private let configuration: FFmpegCaptureConfiguration

    /// Cap on captured stderr (bytes) retained for diagnostics on failure.
    private static let stderrLimit = 64 * 1024

    public init(configuration: FFmpegCaptureConfiguration) {
        self.configuration = configuration
    }

    public func capture() -> AsyncThrowingStream<CapturedFrame, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try prepareOutputDirectory()
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask { try await runFFmpeg() }
                        group.addTask { try await emitFrames(into: continuation) }
                        // Whichever child finishes first ends the capture; cancel
                        // the other and let the group drain.
                        try await group.next()
                        group.cancelAll()
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - ffmpeg process

    private func runFFmpeg() async throws {
        var options = PlatformOptions()
        options.teardownSequence = [
            .gracefulShutDown(allowedDurationToNextStep: configuration.terminationGracePeriod)
        ]

        let result = try await run(
            .name(configuration.executableName),
            arguments: Arguments(configuration.arguments),
            platformOptions: options,
            output: .discarded,
            error: .string(limit: Self.stderrLimit)
        )

        // A non-success status is only a real failure when we did not ask ffmpeg
        // to stop: cancellation tears it down with a signal, which is expected.
        guard result.terminationStatus.isSuccess || Task.isCancelled else {
            throw FrameCaptureError.ffmpegFailed(
                status: result.terminationStatus,
                stderr: result.standardError ?? ""
            )
        }
    }

    // MARK: - Frame discovery

    /// Watches the output directory until the surrounding task is cancelled,
    /// scanning once per `pollInterval`. ffmpeg writes files rather than piping
    /// frames, and event-based watching (`DispatchSource`/kqueue) is Darwin-only,
    /// so polling is the portable choice for the Linux deployment.
    private func emitFrames(
        into continuation: AsyncThrowingStream<CapturedFrame, any Error>.Continuation
    ) async throws {
        var scanner = FrameScanner(
            directory: configuration.outputDirectory,
            imagesDirectory: configuration.imagesDirectory,
            suffix: "." + configuration.fileExtension
        )

        while !Task.isCancelled {
            for frame in scanner.newFrames() {
                continuation.yield(frame)
            }
            try await Task.sleep(for: configuration.pollInterval)
        }
    }

    private func prepareOutputDirectory() throws {
        try FileManager.default.createDirectory(
            at: configuration.outputDirectory,
            withIntermediateDirectories: true
        )
    }
}

/// Stateful directory scan that turns frame files into `CapturedFrame`s.
/// `newFrames()` returns only frames not yet reported, and only once a file's
/// size is stable across two scans — so a frame ffmpeg is still writing is held
/// back until the next scan. Each stable frame is copied to `imagesDirectory`
/// under a timestamp-based name (`YYYY-MM-DD_HH-MM-SS.mmm.jpg`) and the staging
/// file is removed.
private struct FrameScanner {
    let directory: URL
    let imagesDirectory: URL
    let suffix: String

    private let fileManager = FileManager.default
    private var emitted: Set<String> = []
    private var pendingSizes: [String: Int] = [:]

    // DateFormatter is not thread-safe, but FrameScanner is always driven from a single Task.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        // POSIX locale so the fixed numeric format stays stable regardless of the
        // host locale (non-Gregorian calendars / non-ASCII digits otherwise).
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    init(directory: URL, imagesDirectory: URL, suffix: String) {
        self.directory = directory
        self.imagesDirectory = imagesDirectory
        self.suffix = suffix
    }

    mutating func newFrames() -> [CapturedFrame] {
        let names = ((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(suffix) && !emitted.contains($0) }
            .sorted()

        var frames: [CapturedFrame] = []
        for name in names {
            let url = directory.appendingPathComponent(name)
            let attrs = (try? fileManager.attributesOfItem(atPath: url.path)) ?? [:]
            let size = attrs[.size] as? Int ?? 0
            guard size > 0 else { continue }

            guard pendingSizes[name] == size else {
                pendingSizes[name] = size
                continue
            }
            pendingSizes[name] = nil

            let fileDate = attrs[.modificationDate] as? Date ?? Date()
            let result = copyToImages(from: url, date: fileDate)
            // Only remember files we could not delete. Once the staging file is
            // gone it can never be re-listed, so tracking it would grow `emitted`
            // unbounded for the lifetime of the capture.
            if !result.stagingRemoved {
                emitted.insert(name)
            }
            frames.append(CapturedFrame(url: url, index: frameIndex(from: name), detectedAt: fileDate, imagePath: result.path))
        }
        return frames
    }

    /// Copies the staging frame into `imagesDirectory` under a timestamp name and
    /// deletes the original. Returns the destination path (`nil` on copy failure)
    /// and whether the staging file was removed.
    private func copyToImages(from url: URL, date: Date) -> (path: String?, stagingRemoved: Bool) {
        let ms = Int(date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1000)
        let base = String(format: "%@.%03d", Self.dateFormatter.string(from: date), ms)
        do {
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            // Two frames can land in the same millisecond; disambiguate so the
            // copy never collides (a collision would drop the image and leave the
            // staging file orphaned on disk).
            let destination = uniqueDestination(base: base)
            try fileManager.copyItem(at: url, to: destination)
            let stagingRemoved = (try? fileManager.removeItem(at: url)) != nil
            return (destination.path, stagingRemoved)
        } catch {
            return (nil, false)
        }
    }

    /// Returns a path in `imagesDirectory` that does not yet exist, appending a
    /// counter to `base` if a file with that name is already present.
    private func uniqueDestination(base: String) -> URL {
        var candidate = imagesDirectory.appendingPathComponent(base + suffix)
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = imagesDirectory.appendingPathComponent("\(base)-\(counter)\(suffix)")
            counter += 1
        }
        return candidate
    }

    /// Parses the trailing run of digits from a frame filename
    /// (`frame-00042.jpg` → `42`), or `nil` if there is none.
    private func frameIndex(from name: String) -> Int? {
        let stem = name.prefix { $0 != "." }
        let digits = stem.suffix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }
}
