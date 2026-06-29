import SwiftUI
import CatscanAPI

/// Detail for a single flap event: the full snapshot plus its metadata.
struct FlapEventDetailView: View {
    let event: FlapEvent
    let imageURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RemoteImageView(url: imageURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 240, maxHeight: 360)
                    .background(Color.black.opacity(imageURL == nil ? 0 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                metadataCard
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(L10n.EventDetail.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            detailRow(L10n.EventDetail.date,
                      value: Text(event.timestamp.formatted(date: .complete, time: .omitted)))
            Divider().padding(.leading, 16)
            detailRow(L10n.EventDetail.time,
                      value: Text(event.timestamp.formatted(date: .omitted, time: .standard)))
            Divider().padding(.leading, 16)
            detailRow(L10n.EventDetail.captured,
                      value: Text(event.timestamp.formatted(.relative(presentation: .named))))
            Divider().padding(.leading, 16)
            detailRow(L10n.EventDetail.snapshot,
                      value: Text(event.imagePath == nil ? L10n.EventDetail.snapshotNone
                                                         : L10n.EventDetail.snapshotAvailable))
            Divider().padding(.leading, 16)
            detailRow(L10n.EventDetail.eventID, value: Text(shortID))
        }
        .cardStyle()
    }

    /// One metadata row. `title` is a localized label; `value` is passed as a
    /// `Text` so callers control whether it's localized (e.g. snapshot status)
    /// or rendered verbatim (already-formatted dates, the event ID).
    private func detailRow(_ title: LocalizedStringKey, value: Text) -> some View {
        LabeledContent {
            value
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var shortID: String {
        event.id.count > 8 ? String(event.id.prefix(8)).uppercased() : event.id.uppercased()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        FlapEventDetailView(
            event: FlapEvent(id: UUID().uuidString, timestamp: .now, imagePath: "/images/sample.jpg"),
            imageURL: nil
        )
    }
}
#endif
