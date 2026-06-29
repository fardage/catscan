import SwiftUI
import AVKit

/// Plays the camera's HLS (`.m3u8`) live stream with consistent loading / failure
/// placeholders, mirroring `RemoteImageView`'s phase-based handling.
///
/// Autoplays muted (the stream carries no audio) and pauses when it leaves the
/// screen so it isn't streaming behind a pushed detail view, the Settings sheet,
/// or in the background. A failed stream surfaces a tappable retry placeholder.
struct LiveStreamView: View {
    let url: URL
    /// Whether the card is the foremost content. The caller drops this when the
    /// stream is covered by something that doesn't trigger `onDisappear` — e.g.
    /// the Settings sheet presented over the dashboard.
    var isActive: Bool = true

    @State private var model = LiveStreamModel()
    @Environment(\.scenePhase) private var scenePhase

    /// Play only while on-screen, foremost, and the app is foregrounded.
    private var shouldPlay: Bool { isActive && scenePhase == .active }

    var body: some View {
        ZStack {
            if model.phase == .failed {
                failurePlaceholder
            } else {
                if let player = model.player {
                    VideoPlayer(player: player)
                }
                if model.phase != .playing {
                    loadingPlaceholder
                }
            }
        }
        // Configures the player and starts it; restarts when the URL changes and
        // resumes when the card reappears.
        .task(id: url) { model.start(url: url) }
        // Pause when covered by a sheet or backgrounded; resume when frontmost
        // again. (`onDisappear` doesn't fire for sheet presentation.)
        .onChange(of: shouldPlay) { _, play in
            if play { model.start(url: url) } else { model.pause() }
        }
        .onDisappear { model.pause() }
    }

    private var loadingPlaceholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            VStack(spacing: 8) {
                ProgressView()
                Text(L10n.Dashboard.streamLoading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var failurePlaceholder: some View {
        Button {
            model.retry()
        } label: {
            ZStack {
                Rectangle().fill(.quaternary)
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text(L10n.Dashboard.streamUnavailable)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}
