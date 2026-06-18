import struct Foundation.URL
import Subprocess

/// Everything the ffmpeg capturer needs to know. All of it is infrastructure
/// configuration, so it lives in the Data layer and is injected by the App
/// layer — most importantly `outputDirectory`, which is supplied rather than
/// hardcoded so deployments (e.g. a Docker volume at `/app/events`) can point it
/// wherever the runtime user can write.
public struct FFmpegCaptureConfiguration: Sendable {
    /// The input the camera exposes, e.g. `rtsp://192.168.0.51:8554/cam`.
    public var source: String
    /// Directory the frame files are written to. Created if it does not exist.
    public var outputDirectory: URL
    /// `printf`-style filename pattern handed to ffmpeg, e.g. `frame-%05d.jpg`.
    public var filenamePattern: String
    /// Scene-change score above which a frame is emitted (the `gt(scene, …)`).
    public var sceneThreshold: Double
    /// RTSP transport, e.g. `tcp`.
    public var rtspTransport: String
    /// Name (resolved on `PATH`) of the ffmpeg executable.
    public var executableName: String
    /// How often the output directory is scanned for new frames.
    public var pollInterval: Duration
    /// Grace period ffmpeg is given to exit on `SIGTERM` before `SIGKILL`.
    public var terminationGracePeriod: Duration

    public init(
        source: String,
        outputDirectory: URL,
        filenamePattern: String = "frame-%05d.jpg",
        sceneThreshold: Double = 0.1,
        rtspTransport: String = "tcp",
        executableName: String = "ffmpeg",
        pollInterval: Duration = .milliseconds(500),
        terminationGracePeriod: Duration = .seconds(2)
    ) {
        self.source = source
        self.outputDirectory = outputDirectory
        self.filenamePattern = filenamePattern
        self.sceneThreshold = sceneThreshold
        self.rtspTransport = rtspTransport
        self.executableName = executableName
        self.pollInterval = pollInterval
        self.terminationGracePeriod = terminationGracePeriod
    }

    /// The fully-resolved output path (directory + pattern) passed to ffmpeg.
    var outputPattern: String {
        outputDirectory.appendingPathComponent(filenamePattern).path
    }

    /// File extension implied by `filenamePattern`, used to filter the directory
    /// scan. Defaults to `jpg` when the pattern carries no extension.
    var fileExtension: String {
        let ext = URL(fileURLWithPath: filenamePattern).pathExtension
        return ext.isEmpty ? "jpg" : ext
    }

    /// The ffmpeg argument vector equivalent to the documented command line.
    /// Note the single quotes around the `gt(...)` expression are literal: they
    /// are ffmpeg's own filtergraph quoting (protecting the inner comma), not
    /// shell quoting, so they belong in the argument even without a shell.
    var arguments: [String] {
        [
            "-rtsp_transport", rtspTransport,
            "-i", source,
            "-vf", "select='gt(scene,\(sceneThreshold))',format=yuvj420p",
            "-fps_mode", "vfr",
            outputPattern,
        ]
    }
}

/// Failures surfaced by the ffmpeg capturer.
public enum FrameCaptureError: Error, Sendable {
    /// ffmpeg exited on its own with a non-success status (it is expected to run
    /// until the capture is cancelled). Carries the captured stderr tail.
    case ffmpegFailed(status: TerminationStatus, stderr: String)
}
