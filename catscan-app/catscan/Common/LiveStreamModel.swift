import Foundation
import AVKit
import Observation

/// Owns the `AVPlayer` for a `LiveStreamView`, tracking readiness/failure so the
/// view can show the right placeholder. Kept separate (like the app's other view
/// models) because driving the player needs KVO on the item's load status.
@Observable
@MainActor
final class LiveStreamModel {
    enum Phase {
        case idle
        case loading
        case playing
        case failed
    }

    private(set) var phase: Phase = .idle
    private(set) var player: AVPlayer?

    private var url: URL?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?

    /// Builds the player for `url` and starts muted playback. Resumes in place if
    /// already configured for the same (still-healthy) URL.
    func start(url: URL) {
        if self.url == url, let player, phase != .failed {
            player.play()
            return
        }
        self.url = url
        configurePlayer(for: url)
    }

    /// Rebuilds the player item after a failure and tries again.
    func retry() {
        guard let url else { return }
        configurePlayer(for: url)
    }

    func pause() {
        player?.pause()
    }

    private func configurePlayer(for url: URL) {
        statusObservation?.invalidate()
        phase = .loading

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true               // the stream has no audio; stay silent
        player.allowsExternalPlayback = false
        self.player = player

        // `status` reports whether the stream loaded; a bad URL or unreachable
        // host lands on `.failed`. KVO may fire off the main thread, so hop back.
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            let status = observedItem.status
            Task { @MainActor [weak self] in self?.handle(status: status, for: observedItem) }
        }

        player.play()
    }

    private func handle(status: AVPlayerItem.Status, for item: AVPlayerItem) {
        // Ignore a callback that was already in flight when the item was replaced
        // (URL change / retry), so a stale status can't clobber the new player.
        guard item === player?.currentItem else { return }
        switch status {
        case .readyToPlay:
            phase = .playing
            player?.play()
        case .failed:
            phase = .failed
        case .unknown:
            phase = .loading
        @unknown default:
            phase = .loading
        }
    }
}
