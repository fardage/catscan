import Vapor
import NIOConcurrencyHelpers
import Domain
import Data

/// App-layer composition that runs the camera capture for the lifetime of the
/// application: on boot it starts ffmpeg, turns each detected frame into a
/// persisted `FlapEvent`, and on shutdown it cancels the capture (which tears
/// ffmpeg down via the configured `SIGTERM`→`SIGKILL` sequence).
///
/// It lives here — the composition root — because it is the one place allowed to
/// know the concrete Data service, the Domain use case, and Vapor's lifecycle at
/// the same time.
final class FrameCaptureLifecycleHandler: LifecycleHandler {
    private let configuration: FFmpegCaptureConfiguration
    /// Reconnect delay after the capture fails (e.g. the RTSP feed drops).
    private let retryDelay: Duration
    private let task = NIOLockedValueBox<Task<Void, Never>?>(nil)

    init(configuration: FFmpegCaptureConfiguration, retryDelay: Duration = .seconds(5)) {
        self.configuration = configuration
        self.retryDelay = retryDelay
    }

    func didBootAsync(_ app: Application) async throws {
        let service = FFmpegFrameCaptureService(configuration: configuration)
        let createEvent = CreateFlapEventUseCase(
            repository: LiveRepositoryProvider(database: app.db).flapEvents
        )
        let logger = app.logger
        let retryDelay = retryDelay

        task.withLockedValue {
            $0 = Task {
                await Self.supervise(
                    service: service,
                    createEvent: createEvent,
                    retryDelay: retryDelay,
                    logger: logger
                )
            }
        }
        app.logger.notice("Frame capture started", metadata: ["source": .string(configuration.source)])
    }

    func shutdownAsync(_ app: Application) async {
        let running = task.withLockedValue { task -> Task<Void, Never>? in
            defer { task = nil }
            return task
        }
        running?.cancel()
        await running?.value
    }

    /// Consumes the frame stream, persisting an event per frame, and reconnects
    /// after a failure until the task is cancelled.
    private static func supervise(
        service: some FrameCaptureService,
        createEvent: CreateFlapEventUseCase,
        retryDelay: Duration,
        logger: Logger
    ) async {
        while !Task.isCancelled {
            do {
                for try await frame in service.capture() {
                    let event = try await createEvent.execute(FlapEvent(timestamp: frame.detectedAt))
                    logger.info("Recorded flap event", metadata: [
                        "frame": .string(frame.url.lastPathComponent),
                        "eventID": .string(event.id?.uuidString ?? "?"),
                    ])
                }
                // Stream finished cleanly — only happens on cancellation.
            } catch {
                guard !Task.isCancelled else { break }
                logger.error("Frame capture failed; reconnecting", metadata: [
                    "error": .string(String(describing: error)),
                ])
                try? await Task.sleep(for: retryDelay)
            }
        }
    }
}
