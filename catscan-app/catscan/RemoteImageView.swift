import SwiftUI
import UIKit
import CatscanAPI

/// Loads a remote image with consistent loading / failure / empty placeholders.
///
/// Backed by a custom loader rather than `AsyncImage` because `AsyncImage` never
/// retries and isn't cached: a single transient failure — or a request SwiftUI
/// cancels while the dashboard re-renders during a refresh — leaves the thumbnail
/// stuck on the failure placeholder. `.task(id:)` here only restarts when the URL
/// actually changes, results are cached in memory, and failures are retryable.
struct RemoteImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var phase: Phase = .empty

    private enum Phase {
        case empty
        case loading
        case success(UIImage)
        case failure
    }

    var body: some View {
        content
            .task(id: url) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .success(let image):
            if contentMode == .fill {
                // Fill via an overlay on a flexible `Color.clear` so the image
                // takes the proposed size instead of dictating it. A fill image
                // with only a height constraint otherwise reports an oversized
                // width, which a card's `.frame(maxWidth: .infinity)` happily
                // adopts — making it bleed past the surrounding padding.
                Color.clear
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipped()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        case .failure:
            Button {
                Task { await load(force: true) }
            } label: {
                placeholder(symbol: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        case .loading:
            ZStack {
                Rectangle().fill(.quaternary)
                ProgressView()
            }
        case .empty:
            placeholder(symbol: "cat")
        }
    }

    private func load(force: Bool = false) async {
        guard let url else {
            phase = .empty
            return
        }
        if !force, let cached = await ImageCache.shared.cached(url) {
            phase = .success(cached)
            return
        }
        phase = .loading
        // One automatic retry smooths over transient failures before we surface
        // the (still tappable) failure placeholder.
        for attempt in 0..<2 {
            do {
                phase = .success(try await ImageCache.shared.load(url))
                return
            } catch {
                // A cancelled load (the URL changed or the view went away) must
                // not fall through to the failure placeholder — a replacement
                // `.task(id:)` may already have produced a newer image, and the
                // cancelled task would clobber it. `URLSession` surfaces
                // cancellation as `URLError(.cancelled)`, not `CancellationError`.
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    return
                }
                if attempt == 0 { try? await Task.sleep(for: .milliseconds(400)) }
            }
        }
        guard !Task.isCancelled else { return }
        phase = .failure
    }

    private func placeholder(symbol: String) -> some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}

/// In-memory image cache + loader shared across every `RemoteImageView`, so the
/// dashboard, history, and detail views reuse the same decoded bytes.
actor ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    /// Downloads currently in flight, so concurrent requests for the same URL
    /// (e.g. the hero card and a recent-activity row showing the same snapshot)
    /// share one network fetch instead of issuing duplicates.
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let existing = inFlight[url] { return try await existing.value }

        let task = Task { try await Self.fetch(url) }
        inFlight[url] = task
        defer { inFlight[url] = nil }

        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    private static func fetch(_ url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
    }
}

/// A single flap-event row: snapshot thumbnail, time, and relative age.
/// Shared between the dashboard's "Recent Activity" list and the full history.
struct EventRow: View {
    let event: FlapEvent

    var body: some View {
        HStack(spacing: 12) {
            RemoteImageView(url: AppEnvironment.imageURL(for: event.imagePath))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(event.timestamp.formatted(.relative(presentation: .named)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// A card of flap-event rows separated by hairline dividers, each pushing the
/// event's detail. Shared by the dashboard's "Recent Activity" preview and the
/// full history's day sections so the row layout lives in one place.
struct EventListCard: View {
    let events: [FlapEvent]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                NavigationLink {
                    FlapEventDetailView(event: event)
                } label: {
                    EventRow(event: event)
                }
                .buttonStyle(.plain)

                if index < events.count - 1 {
                    Divider().padding(.leading, 84)
                }
            }
        }
        .cardStyle()
    }
}
